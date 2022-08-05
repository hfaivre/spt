pipeline {
    environment {
        registry = "hfaivresaito/petc"
        registryCredential = 'dockerhub_id'
        dockerImage = ''
        CI = true
        ARTIFACTORY_ACCESS_TOKEN = credentials('jfrog_token')
    }
    agent any
    tools {
        maven "maven"
        jdk "jdk"
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn -B -DskipTests -Dcheckstyle.skip clean package'
                archiveArtifacts artifacts: '**/*.jar'
            }
        }
        stage('Test') { 
            steps {
                sh 'mvn test -Dcheckstyle.skip' 
            }
        }
        stage('Docker Build') {
            steps {
                script {
                    dockerImage = docker.build registry + ":$BUILD_NUMBER"
                }
            }
        }
        stage('Deploy our image') {
            steps{
                script {
                    docker.withRegistry( '', registryCredential ) {
                    dockerImage.push()
                    dockerImage.push("latest")
                    }
                }
            }
        }
        stage('Upload to Artifactory') {
          agent {
                docker {
                    image 'releases-docker.jfrog.io/jfrog/jfrog-cli-v2:2.2.0' 
                    reuseNode true
                }
          }
          steps {
            sh 'jfrog rt upload --url http://192.168.1.74:8082/artifactory/ --access-token ${ARTIFACTORY_ACCESS_TOKEN} target/spring-petclinic-2.7.0-SNAPSHOT.jar petclinic/'
          }
        }
    }
}
