pipeline {
    agent any
    tools {
        maven 'MAVEN3.9'
        jdk 'JDK17'
    }

    environment {
        TEAMS_WEBHOOK = 'https://mmmutgkp.webhook.office.com/webhookb2/acd9b1e9-7637-4f8a-9611-9546f4a0cae9@d0732ed6-a89f-488d-b29d-e5e9e7cdde5c/JenkinsCI/41f7c0d803d14461af0c74fe5834c1e6/54066a31-27ea-43fc-8f80-fa31f39edb6c/V2-EDRWdM70sVIS33GCWvQvZzNAFY9akRCo6Y6PoedFYQ1'
        NEXUS_DOCKER_REGISTRY = '192.168.56.11:8085'
        DOCKER_REPO = 'vlink-image'
        DOCKER_IMAGE_NAME = 'vlink'
    }

    options {
        // Teams webhook notifications
        office365ConnectorWebhooks([[
            name: 'fintech-webhook',
            url: TEAMS_WEBHOOK,
            startNotification: false,
            notifySuccess: true,
            notifyAborted: true,
            notifyNotBuilt: true,
            notifyUnstable: true,
            notifyFailure: true,
            notifyBackToNormal: true,
            notifyRepeatedFailure: false,
            timeout: 30000
        ]])
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
                echo 'Testing...'
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
                    artifacts: [[
                        artifactId: 'vLink',
                        classifier: '',
                        file: 'target/vprofile-v2.war',
                        type: 'war'
                    ]]
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
                        whoami
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
            script {
                // Get commit details
                def commitMsg = sh(script: "git log -1 --pretty=%B", returnStdout: true).trim()
                def commitAuthor = sh(script: "git log -1 --pretty=%an", returnStdout: true).trim()
                def commitId = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                def branchName = env.BRANCH_NAME ?: "main"

                // Links
                def nexusBaseUrl = "http://192.168.56.11:9081/repository/vLink-repo"
                def groupIdPath = "QA"
                def artifactId = "vLink"
                def version = "${env.BUILD_NUMBER}v-${env.BUILD_TIMESTAMP}"
                def type = "war"
                def artifactFileName = "${artifactId}-${version}.${type}"
                def nexusArtifactLink = "${nexusBaseUrl}/${groupIdPath}/${artifactId}/${version}/${artifactFileName}"
                def dockerImageLink = "http://192.168.56.11:8085/#browse/browse:${DOCKER_REPO}:${DOCKER_IMAGE_NAME}"
                def consoleLogLink = "${env.BUILD_URL}console"

                // Build status & color
                def buildStatus = (currentBuild.result == null || currentBuild.result == 'SUCCESS') ? 'Success' : currentBuild.result
                def buildColor = (buildStatus == 'Success') ? '#00FF00' :
                                 (buildStatus == 'FAILURE') ? '#FF0000' :
                                 (buildStatus == 'UNSTABLE') ? '#FFA500' : '#808080'

                // Teams notification
                office365ConnectorSend(
                    webhookUrl: TEAMS_WEBHOOK,
                    message: """**Jenkins Build Notification**  
                    ➡️ *Job:* ${env.JOB_NAME}  
                    ➡️ *Build #:* ${env.BUILD_NUMBER}  
                    ➡️ *Branch:* ${branchName}  
                    ➡️ *Commit:* [${commitId}](${consoleLogLink}) by *${commitAuthor}*  
                    ➡️ *Message:* ${commitMsg}  
                    ➡️ *Artifact:* [${artifactFileName}](${nexusArtifactLink})  
                    ➡️ *Docker Image:* [${DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}](${dockerImageLink})  
                    ➡️ *Logs:* [View Console Output](${consoleLogLink})  
                    """,
                    status: buildStatus,
                    color: buildColor
                )
            }
        }
    }
}
