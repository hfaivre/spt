## Setting up Jenkins

1. Setup a jenkins instance. For the exercise, I chose to use a container installation following this Jenkins guide : https://www.jenkins.io/doc/book/installing/docker/

Following each step of this setup is important to ensure that the Jenkins container has access to the Docker Daemon, which will be important for deployinfg our code as an image.

2. Login to management console. Once connected to the instance on my browser (http://locahost:8080), we can login to the Jenkins management interface with `initialAdminPassword` available within the jenkins container at `/var/jenkins_home/secrets`. After having installing the recommended plugins, we can configure Maven and JDK settings under ** Manage Jenkins > Global Tool Configuration**.

## Setup our pipeline

Once that's done, let's start creating a pipeline in the management console.

I create a new pipeline named `my_pipeline` and configure the definition to be a Pipeline SCM, to pull the source code and pipeline steps from our github repository `https://github.com/hfaivre/spt`, specifying to build only for the main branch. Once that is done, we will need to setup a Jenkinsfile describing our pipeline step.

Our goal is to have the following steps : 
1. Compile the Code
2. Run the tests
3. Building the Docker image
4. Pushing the Docker image to Dockerhub
5. [Bonus] Pushing the docker image to Artifactory

To Compile the code and run the tests, we can add these first two stages to the Jenkinsfile : 

```
pipeline {
    agent any
    tools {
        maven "maven"
        jdk "jdk"
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn -B -DskipTests clean package'
                archiveArtifacts artifacts: '**/*.jar'
            }
        }
        stage('Test') { 
            steps {
                sh 'mvn test' 
            }
        }
    }
}
```

Once that is done, let's setup our pipeline for packaging our project in a Docker image.

First we'll install the Docker Pipeline Plugin on Jenkins under **Manage Jenkins > Manage Plugins**, as well as create a global credentials **Manage Jenkins > Manage Credentials** called `dockerhub_id` containing my Dockerhub credentials.

Then we can modify our existing pipeline as follows : 

```
pipeline {
    environment {
    registry = "hfaivresaito/petc"
    registryCredential = 'dockerhub_id'
    dockerImage = ''
}
    agent any
    tools {
        maven "maven"
        jdk "jdk"
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn -B -DskipTests clean package'
                archiveArtifacts artifacts: '**/*.jar'
            }
        }
        stage('Test') { 
            steps {
                sh 'mvn test' 
            }
        }
        
        stage('Docker Build') {
            steps {
                script {
                    dockerImage = docker.build registry + ":$BUILD_NUMBER"
                }
            }
        }
        stage('Docker Push') {
            steps{
                script {
                    docker.withRegistry( '', registryCredential ) {
                    dockerImage.push()
                    dockerImage.push("latest")
                    }
                }
            }
        }
    }
}
```

This adds a **Docker Build** step as well as a **Docker Push** stage. The environment section on the top section allows us to pull our `dockerhub_id` credentials, which will be used during the push phase. 

For the `docker.build` command to work, we need to create a Dockerfile within our repo : 

```
FROM openjdk:19-jdk-alpine3.15
COPY /target/spring-petclinic-2.7.0-SNAPSHOT.jar /home/spring-petclinic-2.7.0-SNAPSHOT.jar 
CMD ["java","-jar","/home/spring-petclinic-2.7.0-SNAPSHOT.jar"]
```

If we now trigger our build on jenkins, we can see the pipeline executing each step successfully, and the image is pushed to Docker Hub successsfully : https://hub.docker.com/repository/docker/hfaivresaito/petc/tags?page=1&ordering=last_updated

It's now possible to run to image locally with the following command : 

```
docker run -p 8085:8080 hfaivresaito/petc:latest
```




## [Bonus] Setup Artifactory



First let's follow [installation instructions](https://www.jfrog.com/confluence/display/JFROG/Installing+Artifactory) to prepare our environment to install Artifactory. Execute following commands to setup home directory

```
mkdir -p $JFROG_HOME/artifactory/var/etc/
cd $JFROG_HOME/artifactory/var/etc/
touch ./system.yaml
chown -R 1030:1030 $JFROG_HOME/artifactory/var
```

We can then start the artifactory container : 

```
$ docker run --name artifactory -v $JFROG_HOME/artifactory/var/:/var/opt/jfrog/artifactory -d -p 8081:8081 -p 8082:8082 releases-docker.jfrog.io/jfrog/artifactory-oss:latest
```


Once that is done, we can install the Artifactory plugin in Jenkins under **Manage Jenkins > Manage Plugins**. Once that's done we can configure the connection with Artifactory under **Manage Jenkins > Configure System **, with the following items : 
- the Instance ID name as `artifactory`,
- the Jfrog Platform URL to point to the public IP of the Artifactory container on port 8082, 
- the username and password used to connect to artifactory




From this point on, I then attempted to modify the Jenkinsfile to add the following steps to push the Docker image to my Artifactory : 
```
pipeline {
    agent any

    stages {
        stage ('Clone') {
            steps {
                git branch: 'master', url: "https://github.com/hfaivre/spt.git"
            }
        }

        stage ('Artifactory configuration') {
            steps {
                rtServer (
                    id: "ARTIFACTORY_SERVER",
                    url: SERVER_URL,
                    credentialsId: CREDENTIALS
                )
            }
        }

        stage ('Build docker image') {
            steps {
                script {
                    docker.build(ARTIFACTORY_DOCKER_REGISTRY + '/petclinc:latest', '.')
                }
            }
        }

        stage ('Push image to Artifactory') {
            steps {
                rtDockerPush(
                    serverId: "ARTIFACTORY_SERVER",
                    image: ARTIFACTORY_DOCKER_REGISTRY + '/hello-petclinc:latest',
                    targetRepo: 'docker-local',
                    properties: 'project-name=docker1;status=stable'
                )
            }
        }

        stage ('Publish build info') {
            steps {
                rtPublishBuildInfo (
                    serverId: "ARTIFACTORY_SERVER"
                )
            }
        }
    }
}
```
Note : this requires to add the `SERVER_URL`, `ARTIFACTORY_DOCKER_REGISTRY`, `CREDENTIALS` as parameters of the Jenkins pipeline.
Unfortunately my pipeline was not able to push the image due to the following error : 

```
INFO: Pushing image: docker-artifactory/pet-clinic:latest
com.github.dockerjava.api.exception.DockerClientException: Could not push image: unauthorized: incorrect username or password
```
After having crossed check credentials, I suspect the docker client is not authorized to communicate with the Docker, but I am uncertain why. Maybe this is because of the fact that the repo used `ARTIFACTORY_DOCKER_REGISTRY` was a generic repo (no docker repo available in the free tier) ?
