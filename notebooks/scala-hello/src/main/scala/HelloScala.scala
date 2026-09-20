import org.apache.spark.sql.SparkSession

object HelloScala {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder().appName("hello-scala").enableHiveSupport().getOrCreate()
    val rows = spark.sql("select category, count(*) as products from shop.products group by category order by category").collect().toList
    println(s"SCALA_ROWS ${rows.mkString(", ")}")
    println(s"SCALA_VERSION ${scala.util.Properties.versionNumberString}")
    spark.stop()
  }
}
