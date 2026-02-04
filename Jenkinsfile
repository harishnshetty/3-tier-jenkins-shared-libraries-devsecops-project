@Library('Jenkins_shared_library') _
def COLOR_MAP = [
    'FAILURE' : 'danger',
    'SUCCESS' : 'good'
]

pipeline{
    agent any
    parameters {
        choice(name: 'action', choices: 'create\ndelete', description: 'Select action to perform (create/delete).')
        
        string(name: 'gitUrl', defaultValue: 'https://github.com/harishnshetty/3-tier-jenkins-shared-libraries-devsecops-project.git', description: 'Git URL')
        string(name: 'gitBranch', defaultValue: 'frontend', description: 'Git Branch')

        string(name: 'projectName', defaultValue: 'frontend', description: 'Project Name')
        string(name: 'projectKey', defaultValue: 'frontend', description: 'Project Key')

        string(name: 'dockerHubUsername', defaultValue: 'harishnshetty', description: 'Docker Hub Username')
        string(name: 'dockerImageName', defaultValue: 'frontend-signed', description: 'Docker Image Name')

         // string(name: 'gitUserConfigName', defaultValue: 'harishn', description: 'Git User Name')
        // string(name: 'gitUserConfigEmail', defaultValue: 'harishn662@gmail.com', description: 'Git User Email')
        // string(name: 'gitUserName', defaultValue: 'harishnshetty', description: 'Git User Name')
        // string(name: 'gitPassword', defaultValue: 'github-token', description: 'Git Password')
        // string(name: 'gitRepo', defaultValue: '3-tier-jenkins-shared-libraries-devsecops-project', description: 'Git Repo')
        // string(name: 'gitBranch', defaultValue: 'deployment', description: 'Git Branch')

        string(name: 'slackChannel', defaultValue: '#devosecops_channel', description: 'Slack Channel')
    }

    tools{
        jdk 'jdk17'
        nodejs 'node20'
    }
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        CONTAINER_PORT = 80
        EXPOSE_PORT = 80
    }
    stages{

        stage('Clean Workspace'){
            steps{
                cleanWorkspace()
            }
        }
        stage('checkout from Git'){
            when { expression { params.action == 'create'}}    

            steps{
                checkoutGit(params.gitUrl, params.gitBranch)
            }
        }
        stage('gitleak'){
            when { expression { params.action == 'create'}}    
            steps{
                gitleak()
            }
        }
        // stage('sonarqube Analysis'){
        // when { expression { params.action == 'create'}}    
        //     steps{
        //         sonarqubeAnalysis()
        //     }
        // }
        // stage('sonarqube QualitGate'){
        // when { expression { params.action == 'create'}}    
        //     steps{
        //         script{
        //             def credentialsId = 'Sonar-token'
        //             qualityGate(credentialsId)
        //         }
        //     }
        // }
        // stage('npm install'){
        // when { expression { params.action == 'create'}}    
        //     steps{
        //         npmInstall()
        //     }
        // }
        
        // stage('Trivy file scan'){
        // when { expression { params.action == 'create'}}    
        //     steps{
        //         trivyFs()
        //     }
        // }


// stage('OWASP FS SCAN') {
//     when { expression { params.action == 'create'} }
//     steps {
//         dependencyCheck(
//             odcInstallation: 'dp-check',
//             additionalArguments: '''
//                 --scan .
//                 --disableYarnAudit
//                 --disableNodeAudit
//             '''
//         )

//         dependencyCheckPublisher(
//             pattern: '**/dependency-check-report-*.xml'
//         )
//     }
// }



        stage('Docker Build'){
        when { expression { params.action == 'create'}}    
            steps{
                dockerBuild()
            }
        }


        stage('Trivy Image Scan'){
        when { expression { params.action == 'create'}}    
            steps{
                trivyImage()
            }
        }

        stage('Docker Push To DockerHub'){
        when { expression { params.action == 'create'}}    
            steps{
                dockerPush()
            }
        }



    //     stage('Updating the k8s Deploymentfile'){
    //         steps{
    //             updateK8sDeploymentFile()
    //         }
    //     }

            stage('SBOM and Cosign Attestation'){
                when { expression { params.action == 'create'}}    
                steps{
                    trivyCosignEnforce()
                }
            }
    //     stage('commit and push to github'){
    //         when { expression { params.action == 'create'}}    
    //         steps{
    //             commitAndPush()
    //         }
    //     }

    // }
        // stage('Manual Approval') {
        //     steps {
        //         script {
        //             try {
        //                 timeout(time: 10, unit: 'MINUTES') {
        //                     input message: 'Approve to run the container'
        //                 }
        //                 env.APPROVED = "true"
        //             } catch (err) {
        //                 echo "⏭️ Approval not granted (aborted or timeout). Skipping deployment."
        //                 env.APPROVED = "false"
        //             }
        //         }
        //     }
        // }

        stage('Manual Approval') {
            steps {
                script {
                    try {
                        timeout(time: 10, unit: 'MINUTES') {
                            input message: 'Approve to update the k8s deployment frontend file'
                        }
                        env.APPROVED = "true"
                    } catch (err) {
                        echo "⏭️ Approval not granted (aborted or timeout). Skipping deployment."
                        env.APPROVED = "false"
                    }
                }
            }
        }

        // stage('Docker Run Container'){
        // when { expression { params.action == 'create'}}    
        //     steps{
        //         dockerRun()
        //     }
        // }


        // stage('Docker Run Container') {
        //     when {
        //         allOf {
        //             expression { env.APPROVED == "true" }
        //             expression { params.action == 'create' }
        //         }
        //     }
        //     steps {
        //         dockerRun()
        //     }
        // }

        stage('show memory'){
            steps{
                sh 'free -h'
            }
        }

    // post {
    //     always {
    //          script{
    //         echo 'Slack Notifications'
    //         slackSend (
    //             channel: params.slackChannel,
    //             color: COLOR_MAP[currentBuild.currentResult],
    //             message: "*${currentBuild.currentResult}:* Job ${env.JOB_NAME} \n build ${env.BUILD_NUMBER} \n More info at: ${env.BUILD_URL}"
    //             )
    //         }
    //     }
    
    }
}