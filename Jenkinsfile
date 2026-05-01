
    
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

                        mkdir -p work/http
                        echo "$ANSIBLE_PUB" > work/http/ansible.pub
                     '''
               }
            }
         }

         stage('Packer Builds') {
            steps {
               withCredentials([string(credentialsId: 'proxmox-id', variable: 'PROXMOX_ID'), string(credentialsId: 'proxmox-secret', variable: 'PROXMOX_SECRET'), string(credentialsId: 'root-password', variable: 'ROOT_PWD'), file(credentialsId: 'proxmox-tfvars', variable: 'PROXMOX_TFVARS')]) {
                     script {
                        dir("work") {
                           def files = sh(script: "ls *.pkr.hcl", returnStdout: true).trim().split()
                           for (file in files) {
                              env.WORKING_FILE = file
                              sh '''
                                 if curl -sk \
                                 -H "Authorization: PVEAPIToken=$PROXMOX_ID=$PROXMOX_SECRET" \
                                 https://10.1.3.10:8006/api2/json/nodes/proxmox/qemu/$(cat $WORKING_FILE | grep vm_id | cut -d'"' -f2)/status/current \
                                 | grep 'not exist' >/dev/null; then
                                    packer init $WORKING_FILE
                                    PACKER_GETTER_READ_TIMEOUT="8h" packer build -var-file="$PROXMOX_TFVARS" -var "root_pwd=$ROOT_PWD" $WORKING_FILE
                                 fi
                              '''
                           }
                        }
                     }
               }
            }
         }

         stage('Terraform Apply') {
            steps {
               withCredentials([string(credentialsId: 'proxmox-id', variable: 'PROXMOX_ID'), string(credentialsId: 'proxmox-secret', variable: 'PROXMOX_SECRET'),file(credentialsId: 'proxmox-tfvars', variable: 'PROXMOX_TFVARS')]) {
                     dir("work") {
                        sh '''
                           terraform init
                           jq -r '.vms[].id' complete.tfvars.json > managed.dat
                           for vmid in $(curl -sk -H "Authorization: PVEAPIToken=$PROXMOX_ID=$PROXMOX_SECRET" https://10.1.3.10:8006/api2/json/nodes/proxmox/qemu/ | jq '.data[].vmid'); do
                              if [[ "$vmid" == "500" && ! "$(terraform state list | grep proxmox_vm_qemu.pfsense)" ]]; then terraform import --var-file=$PROXMOX_TFVARS --var-file=pfsense.tfvars.json --var-file=complete.tfvars.json "proxmox_vm_qemu.pfsense" proxmox/qemu/500
                              else
                                 index=$(grep -n -w "$vmid" managed.dat | cut -d: -f1)
                                 if [[ "$index" && ! "$(terraform state list | grep proxmox_vm_qemu.instances\\\\[$(( index - 1 ))\\\\])" ]]; then
                                    terraform import --var-file=$PROXMOX_TFVARS --var-file=pfsense.tfvars.json --var-file=complete.tfvars.json "proxmox_vm_qemu.instances[$(( index - 1 ))]" proxmox/qemu/$vmid
                                 fi
                              fi
                           done
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

