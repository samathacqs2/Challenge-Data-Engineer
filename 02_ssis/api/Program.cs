using System.Data;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var cfg      = app.Configuration;
var connStr  = cfg.GetConnectionString("Ssisdb") ?? throw new InvalidOperationException("Falta ConnectionStrings:Ssisdb");
var folder   = cfg["Ssis:Folder"]!;
var project  = cfg["Ssis:Project"]!;
var package  = cfg["Ssis:Package"]!;
var apiKey   = cfg["Api:Key"];

// ---------- Autenticacion simple por API key (header X-API-KEY) ----------
app.Use(async (ctx, next) =>
{
    if (ctx.Request.Path.StartsWithSegments("/api"))
    {
        if (!ctx.Request.Headers.TryGetValue("X-API-KEY", out var provided) || provided != apiKey)
        {
            ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await ctx.Response.WriteAsJsonAsync(new { error = "API key invalida o ausente" });
            return;
        }
    }
    await next();
});

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

// ---------- POST /api/etl/beneficios : dispara el paquete SSIS ----------
app.MapPost("/api/etl/beneficios", async (ILogger<Program> log) =>
{
    try
    {
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();

        // 1) Evitar ejecuciones concurrentes del mismo paquete
        //    status: 1=creado 2=ejecutando 5=pendiente 8=deteniendo
        await using (var chk = new SqlCommand(@"
            SELECT COUNT(*) FROM SSISDB.catalog.executions
            WHERE folder_name = @f AND project_name = @p AND package_name = @k
              AND status IN (1,2,5,8)", conn))
        {
            chk.Parameters.AddWithValue("@f", folder);
            chk.Parameters.AddWithValue("@p", project);
            chk.Parameters.AddWithValue("@k", package);
            if ((int)(await chk.ExecuteScalarAsync())! > 0)
                return Results.Conflict(new { error = "Ya hay una ejecucion en curso. Intente luego." });
        }

        // 2) Crear la ejecucion en el catalogo
        long executionId;
        await using (var create = new SqlCommand("SSISDB.catalog.create_execution", conn)
                     { CommandType = CommandType.StoredProcedure })
        {
            create.Parameters.AddWithValue("@folder_name", folder);
            create.Parameters.AddWithValue("@project_name", project);
            create.Parameters.AddWithValue("@package_name", package);
            create.Parameters.AddWithValue("@use32bitruntime", false);
            var outId = new SqlParameter("@execution_id", SqlDbType.BigInt) { Direction = ParameterDirection.Output };
            create.Parameters.Add(outId);
            await create.ExecuteNonQueryAsync();
            executionId = (long)outId.Value;
        }

        // 3) Iniciar (asincrono por defecto: responde de inmediato)
        await using (var start = new SqlCommand("SSISDB.catalog.start_execution", conn)
                     { CommandType = CommandType.StoredProcedure })
        {
            start.Parameters.AddWithValue("@execution_id", executionId);
            await start.ExecuteNonQueryAsync();
        }

        log.LogInformation("Paquete {Package} iniciado. execution_id={Id}", package, executionId);
        return Results.Accepted($"/api/etl/beneficios/{executionId}",
            new { executionId, estado = "Iniciado", consulta = $"/api/etl/beneficios/{executionId}" });
    }
    catch (SqlException ex)
    {
        log.LogError(ex, "Error SQL al iniciar el paquete");
        return Results.Problem(title: "No se pudo iniciar el ETL", detail: ex.Message, statusCode: 500);
    }
});

// ---------- GET /api/etl/beneficios/{id} : estado de una ejecucion ----------
app.MapGet("/api/etl/beneficios/{id:long}", async (long id, ILogger<Program> log) =>
{
    try
    {
        await using var conn = new SqlConnection(connStr);
        await conn.OpenAsync();

        await using var cmd = new SqlCommand(@"
            SELECT status, start_time, end_time
            FROM SSISDB.catalog.executions WHERE execution_id = @id", conn);
        cmd.Parameters.AddWithValue("@id", id);

        int status; DateTimeOffset? inicio, fin;
        await using (var rd = await cmd.ExecuteReaderAsync())
        {
            if (!await rd.ReadAsync()) return Results.NotFound(new { error = "execution_id no existe" });
            status = rd.GetInt32(0);
            inicio = rd.IsDBNull(1) ? null : rd.GetDateTimeOffset(1);
            fin    = rd.IsDBNull(2) ? null : rd.GetDateTimeOffset(2);
        }

        var estado = status switch
        {
            1 => "Creado", 2 => "Ejecutando", 3 => "Cancelado", 4 => "Fallido",
            5 => "Pendiente", 6 => "Terminado inesperadamente", 7 => "Exitoso",
            8 => "Deteniendo", 9 => "Completado", _ => "Desconocido"
        };

        // Si fallo, adjuntar mensajes de error del catalogo (message_type 120 = error)
        var errores = new List<string>();
        if (status is 4 or 6)
        {
            await using var m = new SqlCommand(@"
                SELECT TOP (5) message FROM SSISDB.catalog.event_messages
                WHERE operation_id = @id AND event_name = 'OnError' ORDER BY event_message_id DESC", conn);
            m.Parameters.AddWithValue("@id", id);
            await using var r2 = await m.ExecuteReaderAsync();
            while (await r2.ReadAsync()) errores.Add(r2.GetString(0));
        }

        return Results.Ok(new { executionId = id, estado, inicio, fin, errores });
    }
    catch (SqlException ex)
    {
        log.LogError(ex, "Error SQL al consultar ejecucion {Id}", id);
        return Results.Problem(title: "No se pudo consultar el estado", detail: ex.Message, statusCode: 500);
    }
});

app.Run();
