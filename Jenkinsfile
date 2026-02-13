def COLOR_MAP = [
    'FAILURE' : 'danger',
    'SUCCESS' : 'good'
]
pipeline {
    agent any

    parameters {
        choice(name: 'action', choices: 'create\ndelete', description: 'Select action to perform (create/delete).')
        
        string(name: 'gitUrl', defaultValue: 'https://github.com/harishnshetty/3-tier-jenkins-shared-libraries-devsecops-project.git', description: 'Git URL')
        string(name: 'gitBranch', defaultValue: 'eks-terraform', description: 'Git Branch')
       
        string(name: 'varfile', defaultValue: 'dev', description: 'Environment to deploy')

        string(name: 'slackChannel', defaultValue: '#devsecops', description: 'Slack channel to send notifications')
    }
    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION = "ap-south-1"
    }
    stages {
        stage('Checkout SCM') {
            when {
                expression { params.action == 'create' }
            }
            steps {
                script {
                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: "*/${params.gitBranch}"]],
                        userRemoteConfigs: [[url: "${params.gitUrl}"]]
                    ])
                }
            }
        }
        stage('Initializing Terraform'){
            when { expression { params.action == 'create'}} 
            steps{
                script{
                    sh 'terraform init'
                }
            }
        }
        stage('Formatting Terraform Code'){
            when { expression { params.action == 'create'}} 
            steps{
                script{
                    sh 'terraform fmt'
                }
            }
        }
        stage('Validating Terraform'){
            when { expression { params.action == 'create'}} 
            steps{
                script{
                    sh 'terraform validate'
                }
            }
        }
        stage('Previewing the Infra using Terraform'){
            when { expression { params.action == 'create'}} 
            steps{
                script{
                    sh 'terraform plan -var-file=${env.varfile}.tfvars'
                    input(message: "Are you sure to proceed?", ok: "Proceed")
                }
            }
        }
        stage('Creating/Destroying an EKS Cluster'){
            when { expression { params.action == 'create'}} 
            steps{
                script{
                    sh 'terraform apply -var-file=${env.varfile}.tfvars --auto-approve'
                }
            }
        }
        stage('Destroying an EKS Cluster'){
            when { expression { params.action == 'delete'}} 
            steps{
                script{
                    sh 'terraform destroy -var-file=${env.varfile}.tfvars --auto-approve'
                }
            }
        }
    }

    post{
        always{
            slackSend(
                channel: params.slackChannel,
                color: COLOR_MAP[currentBuild.result],
                message: """
                Pipeline completed for ${env.JOB_NAME} - ${env.BUILD_NUMBER}
                aws eks update-kubeconfig --region ${env.AWS_DEFAULT_REGION} --name ${env.cluster_name}
                """

            )
        }
    }  
}