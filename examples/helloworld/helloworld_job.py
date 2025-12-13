import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Simple demo: create a DataFrame and show it
data = [("Hello", "World", 1), ("AWS", "Glue", 2), ("Demo", "Job", 3)]
columns = ["col1", "col2", "id"]
df = spark.createDataFrame(data, columns)

print("Hello World from AWS Glue!")
df.show()

job.commit()
