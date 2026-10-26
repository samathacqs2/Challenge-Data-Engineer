import os
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("Beneficios").getOrCreate()

# Seguridad: las credenciales salen de variables de entorno.
# Sin valor por defecto: si falta la variable, el programa falla
# en lugar de usar una clave escrita en el código.
db_user = os.environ["DB_USER"]
db_password = os.environ["DB_PASSWORD"]

# Rendimiento: lectura en paralelo por rangos de ID, con fetchsize.
# Ajustar lowerBound y upperBound al mínimo y máximo reales del ID.
df = (spark.read.format("jdbc")
      .option("url", "jdbc:sqlserver://server;databaseName=db")
      .option("dbtable", "EVA.Beneficio")
      .option("user", db_user)
      .option("password", db_password)
      .option("partitionColumn", "ID")
      .option("lowerBound", "1")
      .option("upperBound", "1000000")
      .option("numPartitions", "8")
      .option("fetchsize", "10000")
      .load())

# Calidad de datos: los nulos pasan a texto vacío antes del split,
# para que explode no elimine esas filas.
dia = F.split(F.coalesce(F.col("Dia"), F.lit("")), ",")
df3 = df.withColumn("Dia", F.explode(dia))

# Calidad de datos: sin espacios, tildes ni mayúsculas,
# y se descartan los valores vacíos.
limpio = F.lower(F.trim(F.translate(
    F.col("Dia"), "áéíóúÁÉÍÓÚ", "aeiouAEIOU")))
df4 = df3.withColumn("Dia", limpio).filter(F.col("Dia") != "")

# Conteo inflado: "Lunes,Lunes" no debe contar dos veces el mismo día.
df4 = df4.dropDuplicates(["ID", "Dia"])
df_group = df4.groupBy("Dia").agg(F.count("Dia").alias("total"))

# Resultado invertido: se busca el total máximo (no el mínimo)
# y se devuelven todos los días que empaten.
max_total = df_group.agg(F.max("total")).first()[0]
top = df_group.filter(F.col("total") == max_total).collect()
print("Día(s) más frecuente(s):", [r["Dia"] for r in top])

# Conteo inflado: beneficios únicos sobre el DataFrame original
# (antes del explode) y con countDistinct.
total = df.agg(F.countDistinct("Beneficio")).first()[0]
print("Total beneficios:", total)

spark.stop()

