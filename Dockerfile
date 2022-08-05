FROM openjdk:19-jdk-alpine3.15
COPY /target/spring-petclinic-2.7.0-SNAPSHOT.jar /home/spring-petclinic-2.7.0-SNAPSHOT.jar 
CMD ["java","-jar","/home/spring-petclinic-2.7.0-SNAPSHOT.jar"]
