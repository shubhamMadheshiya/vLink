pipeline {
    agent any
    tools {
        maven 'MAVEN3.9'
        jdk 'JDK17'
    }

    environment {
        NEXUS_DOCKER_REGISTRY = '192.168.56.11:8085'
        DOCKER_REPO = 'vlink-image'
        DOCKER_IMAGE_NAME = 'vlink'
    }

    stages {
        stage('Fetch code') {
            steps {
                echo 'Fetching code...'
                git branch: 'main', url: 'https://github.com/shubhamMadheshiya/vLink.git'
            }
        }

        stage('Build') {
            steps {
                echo 'Building...'
                sh 'mvn install -DskipTests'
            }
        }

        stage('Test') {
            steps {
                echo 'Running tests...'
                sh 'mvn test'
                // junit 'target/surefire-reports/*.xml'
            }
        }

        stage('Checkstyle') {
            steps {
                echo 'Running Checkstyle...'
                sh 'mvn checkstyle:checkstyle'
            }
        }

        stage('Code Analysis with SonarQube') {
            environment {
                scannerHome = tool 'sonar7.2'
            }
            steps {
                withSonarQubeEnv('sonarserver') {
                    sh '''${scannerHome}/bin/sonar-scanner \
                        -Dsonar.projectKey=vLink \
                        -Dsonar.projectName=vLink-repo \
                        -Dsonar.projectVersion=1.0 \
                        -Dsonar.sources=src/ \
                        -Dsonar.java.binaries=target/test-classes/com/visualpathit/account/controllerTest/ \
                        -Dsonar.junit.reportsPath=target/surefire-reports/ \
                        -Dsonar.jacoco.reportsPath=target/jacoco.exec \
                        -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml'''
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                echo 'Waiting for SonarQube Quality Gate...'
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Publish WAR to Nexus Maven Repo') {
            steps {
                nexusArtifactUploader(
                    nexusVersion: 'nexus3',
                    protocol: 'http',
                    nexusUrl: '192.168.56.11:9081',
                    groupId: 'QA',
                    version: "${env.BUILD_NUMBER}v-${env.BUILD_TIMESTAMP}",
                    repository: 'vLink-repo',
                    credentialsId: 'nexuslogin',
                    artifacts: [
                        [
                            artifactId: 'vLink',
                            classifier: '',
                            file: 'target/vprofile-v2.war',
                            type: 'war'
                        ]
                    ]
                )
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo 'Building Docker image...'
                    dockerImage = docker.build("${NEXUS_DOCKER_REGISTRY}/${DOCKER_REPO}/${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}")
                }
            }
        }

        stage('Push Docker Image to Nexus Docker Repo') {
            steps {
                script {
                    echo 'Pushing Docker image to Nexus...'
                    docker.withRegistry("http://${NEXUS_DOCKER_REGISTRY}", 'nexuslogin') {
                        dockerImage.push()
                        dockerImage.push("latest")
                    }
                }
            }
        }

        stage('Ansible Deploy') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexuslogin', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    echo 'Deploying with Ansible...'
                    sh """
                        cd ansible
                        ansible-playbook playbooks/deploy.yml \
                            -i inventories/sit/hosts \
                            -e nexus_registry=${NEXUS_DOCKER_REGISTRY} \
                            -e docker_repo=${DOCKER_REPO} \
                            -e docker_image_name=${DOCKER_IMAGE_NAME} \
                            -e docker_image_tag=${BUILD_NUMBER} \
                            -e nexus_username=${NEXUS_USER} \
                            -e nexus_password=${NEXUS_PASS}
                    """
                }
            }
        }
    }

    post {
        always {
            withCredentials([string(credentialsId: 'fintech-webhook', variable: 'TEAMS_HOOK')]) {
                script {
                    // Collect Git info
                    def commitMsg = sh(returnStdout: true, script: "git log -1 --pretty=%B").trim()
                    def commitId = sh(returnStdout: true, script: "git rev-parse --short HEAD").trim()
                    def commitAuthor = sh(returnStdout: true, script: "git log -1 --pretty=%an").trim()
                    def branchName = env.BRANCH_NAME ?: "main"

                    // Artifact & logs
                    def nexusBaseUrl = "http://192.168.56.11:9081/repository/vLink-repo"
                    def artifactId = "vLink"
                    def version = "${env.BUILD_NUMBER}v-${env.BUILD_TIMESTAMP}"
                    def artifactFileName = "${artifactId}-${version}.war"
                    def nexusArtifactLink = "${nexusBaseUrl}/QA/${artifactId}/${version}/${artifactFileName}"
                    def dockerImageLink = "http://192.168.56.11:8085/#browse/browse:${DOCKER_REPO}:${DOCKER_IMAGE_NAME}"
                    def consoleLogLink = "${env.BUILD_URL}console"

                    // Build status & color
                    def buildStatus = (currentBuild.result == null || currentBuild.result == 'SUCCESS') ? 'SUCCESS' : currentBuild.result
                    def buildColor = (buildStatus == 'SUCCESS') ? '#00FF00' :
                                     (buildStatus == 'FAILURE') ? '#FF0000' :
                                     (buildStatus == 'UNSTABLE') ? '#FFA500' : '#808080'

                    // Send notification
                    office365ConnectorSend(
                        webhookUrl: TEAMS_HOOK,
                        message: """**Jenkins Build Notification**  
                        🔹 *Job:* ${env.JOB_NAME}  
                        🔹 *Build #:* ${env.BUILD_NUMBER}  
                        🔹 *Branch:* ${branchName}  
                        🔹 *Commit:* ${commitId} by ${commitAuthor}  
                        🔹 *Message:* ${commitMsg}  
                        🔹 *Status:* ${buildStatus}  
                        """,
                        status: buildStatus,
                        color: buildColor,
                        facts: [
                            [name: "Artifact", value: "[${artifactFileName}](${nexusArtifactLink})"],
                            [name: "Docker Image", value: "[${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}](${dockerImageLink})"],
                            [name: "Console Logs", value: "[View Logs](${consoleLogLink})"]
                        ]
                    )
                }
            }
        }
    }
}
