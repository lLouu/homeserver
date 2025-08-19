#!/bin/sh
wget http://localhost:8080/jnlpJars/jenkins-cli.jar
## Plugin installation
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) install-plugin workflow-job workflow-aggregator workflow-cps git credentials plain-credentials ssh-credentials ssh-agent

## Restart jenkins for plugin loads
sudo rc-service jenkins restart
sleep 30

## Get Crumb for f****** CSRF
CRUMB=$(curl -s -c cookies.jar -u admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) http://localhost:8080/crumbIssuer/api/json | jq -r '.crumbRequestField + ":" + .crumb')

## Storing ssh private key
curl -s -b cookies.jar -u admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) -X POST "http://localhost:8080/credentials/store/system/domain/_/createCredentials" -H "$CRUMB" -H "Content-Type: application/xml" --data-binary @- <<EOF
<com.cloudbees.plugins.credentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@latest">
  <scope>GLOBAL</scope>
  <id>ansible-key</id>
  <description>Ansible SSH Key</description>
  <username>ansible</username>
  <privateKeySource class="com.cloudbees.plugins.credentials.impl.BasicSSHUserPrivateKey\$DirectEntryPrivateKeySource">
    <privateKey>
      $(cat /var/lib/jenkins/.ssh/id_rsa)
    </privateKey>
  </privateKeySource>
</com.cloudbees.plugins.credentials.impl.BasicSSHUserPrivateKey>
EOF

## Storing proxmox api key
curl -s -b cookies.jar -u admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) -X POST "http://localhost:8080/credentials/store/system/domain/_/createCredentials" -H "$CRUMB" -H "Content-Type: application/xml" --data-binary @- <<EOF
<org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl plugin="plain-credentials@latest">
  <scope>GLOBAL</scope>
  <id>proxmox-tfvars</id>
  <description>Proxmox Terraform Variables</description>
  <fileName>proxmox.tfvars.json</fileName>
  <secretBytes>
      $(base64 -w0 /var/lib/jenkins/.tmp/proxmox.tfvars.json)
  </secretBytes>
</org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl>
EOF

## Storing root pwd
curl -s -b cookies.jar -u admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) -X POST "http://localhost:8080/credentials/store/system/domain/_/createCredentials" -H "$CRUMB" -H "Content-Type: application/xml" --data-binary @- <<EOF
<org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl plugin="plain-credentials@latest">
  <scope>GLOBAL</scope>
  <id>root-password</id>
  <description>Root Password</description>
  <secret>$(cat /var/lib/jenkins/.tmp/root.pwd)</secret>
</org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl>
EOF

rm cookies.jar

## Deploy pipeline
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) create-job homeserver <<EOF
<flow-definition plugin="workflow-job@latest">
  <description>Homeserver build pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@latest">
    <script>
    <![CDATA[
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
                git branch: "\${env.BRANCH}",
                    url: "\${env.REPOSITORY}"
            }
        }

        stage('Prepare Workspace') {
            steps {
                script {
                    sh '''
                        mkdir -p work
                        cp -r terraform/ansible/* work/
                        cp -r terraform/config/* work/
                        cp -r terraform/mainframe/* work/
                        cp -r terraform/packer/* work/
                    '''
                }
            }
        }

        stage('Packer Builds') {
            steps {
                withCredentials([string(credentialsId: 'root-password', variable: 'ROOT_PWD')]) {
                    script {
                        def packerDir = "work"
                        def executedFile = "\${packerDir}/.executed_packer"
                        sh "touch \${executedFile}"

                        def ignored = sh(script: 'echo "\$CACHE"', returnStdout: true).trim().split()
                        def files = sh(script: "ls \${packerDir}/*.pkr.hcl", returnStdout: true).trim().split()

                        for (file in files) {
                            def base = file.tokenize('/').last()
                            if (!(base in ignored)) {
                                if (!readFile(executedFile).contains(base)) {
                                    sh '''
                                        packer build -var-file="work/proxmox.tfvars.json" -var "ansible_pub=\$ANSIBLE_PUB" -var "root_pwd=\$ROOT_PWD" \${file}
                                        echo \${base} >> \${executedFile}
                                    '''

                                }
                            }
                        }
                        def newCache = sh(script: 'echo "\$CACHE" && cat \${executedFile}', returnStdout: true).trim()
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
                            terraform plan --var-file=\$PROXMOX_TFVARS --var-file=pfsense.tfvars.json --var-file=complete.tfvars.json -out plan
                            terraform apply -auto-approve plan
                            rm plan
                        '''
                    }
                }
            }
        }

        stage('Run Ansible Installation') {
            steps {
                sshagent(credentials: ['ansible-key']) {
                    dir("work") {
                        sh "ansible-playbook installation.yml -i hosts"
                    }
                }
            }
        }

        stage('Run Ansible Configuration') {
            steps {
                sshagent(credentials: ['ansible-key']) {
                    dir("work") {
                        sh "ansible-playbook configuration/*.yml -i hosts"
                    }
                }
            }
        }
    }
}
    ]]>
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
</flow-definition>
EOF

## Run first time pipeline
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) build homeserver