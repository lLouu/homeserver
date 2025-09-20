
    
pipeline {
   agent any
   triggers {
         pollSCM('H * * * *')
   }

   stages {
         stage('Lookout environement') {
            steps {
               script {
                     env.BRANCH = readFile('/var/lib/jenkins/.branch').trim()
                     env.REPOSITORY = readFile('/var/lib/jenkins/.repository').trim()
                     env.ANSIBLE_PUB = readFile('/var/lib/jenkins/.ssh/id_rsa.pub').trim()
                     env.CACHE = readFile('/var/lib/jenkins/.cache_homeserver_build').trim()
               }
            }
         }

         stage('Checkout') {
            steps {
               git branch: "${env.BRANCH}",
                     url: "https://github.com${env.REPOSITORY}"
            }
         }

         stage('Prepare Workspace') {
            steps {
               script {
                     sh '''
                        mkdir -p work
                        cp -r jenkins/ansible/* work/
                        cp -r jenkins/configs/* work/
                        cp -r jenkins/terraform/* work/
                        cp -r jenkins/packer/* work/
                     '''
               }
            }
         }

         stage('Packer Builds') {
            steps {
               withCredentials([string(credentialsId: 'root-password', variable: 'ROOT_PWD')]) {
                     script {
                     def packerDir = "work"
                     def executedFile = "${packerDir}/.executed_packer"
                     sh "touch ${executedFile}"

                     def ignored = sh(script: 'echo "$CACHE"', returnStdout: true).trim().split()
                     def files = sh(script: "ls ${packerDir}/*.pkr.hcl", returnStdout: true).trim().split()

                     for (file in files) {
                        def base = file.tokenize('/').last()
                        if (!(base in ignored)) {
                           if (!readFile(executedFile).contains(base)) {
                                 env.WORKING_FILE = file
                                 sh '''
                                    packer init $WORKING_FILE
                                    packer build -var-file="work/proxmox.tfvars.json" -var "ansible_pub=$ANSIBLE_PUB" -var "root_pwd=$ROOT_PWD" $WORKING_FILE
                                    echo ${base} >> ${executedFile}
                                 '''

                           }
                        }
                     }
                     def newCache = sh(script: 'echo "$CACHE" && cat ${executedFile}', returnStdout: true).trim()
                     writeFile file: "/var/lib/jenkins/.cache_homeserver_build", text: newCache
                     }
               }
            }
         }

         stage('Terraform Apply') {
            steps {
               withCredentials([file(credentialsId: 'proxmox-tfvars', variable: 'PROXMOX_TFVARS')]) {
                     dir("work") {
                        sh '''
                           terraform init
                           terraform plan --var-file=$PROXMOX_TFVARS --var-file=pfsense.tfvars.json --var-file=complete.tfvars.json -out plan
                           terraform apply -auto-approve plan
                           rm plan
                        '''
                     }
               }
            }
         }

         stage('Run Ansible Agent') {
            steps {
               sshagent(credentials: ['ansible-key']) {
                     dir("work") {
                        sh "ansible-playbook installation.yml -i hosts.yml -u ansible -e \"branch=$BRANCH repository=$REPOSITORY\""
                     }
               }
            }
         }
   }
}

