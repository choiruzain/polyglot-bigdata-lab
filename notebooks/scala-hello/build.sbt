// Compile against the Spark jars already installed in the image.
// Scala must match the version Spark was built with (Spark 4 uses Scala 2.13).
val sparkHome = file(sys.env.getOrElse("SPARK_HOME", "/opt/spark"))
val sparkScalaVersion: String =
  (sparkHome / "jars" * "scala-library-*.jar").get.headOption
    .map(_.getName.stripPrefix("scala-library-").stripSuffix(".jar"))
    .getOrElse("2.13.16")

ThisBuild / scalaVersion := sparkScalaVersion

lazy val root = (project in file("."))
  .settings(
    name := "hello-scala",
    version := "0.1.0",
    Compile / unmanagedJars ++= (sparkHome / "jars" * "*.jar").classpath
      .filterNot(_.data.getName.matches("scala-(library|reflect|compiler).*"))
  )
