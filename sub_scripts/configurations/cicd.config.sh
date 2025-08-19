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
  
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@latest">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@latest">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>$(cat /var/lib/jenkins/.repository)</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>$(cat /var/lib/jenkins/.branch)</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
</flow-definition>
EOF

## Run first time pipeline
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword) build homeserver