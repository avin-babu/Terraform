pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = "true"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                withAWS(credentials: 'aws-creds', region: 'ap-south-1') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                withAWS(credentials: 'aws-creds', region: 'ap-south-1') {
                    sh 'terraform plan -out=tfplan'
                }
            }
        }

        stage('Approval for Apply') {
            steps {
                timeout(time: 2, unit: 'HOURS') {
                    input message: "Approve to run terraform apply?"
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withAWS(credentials: 'aws-creds', region: 'ap-south-1') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Post Apply Actions') {
            steps {
                sh '''
                    teraform state list
                '''
                echo 'Terraform apply completed successfully.'
            }
        }
    }
}
