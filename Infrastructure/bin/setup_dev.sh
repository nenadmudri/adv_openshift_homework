#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.



# Compile all projects

cd $HOME/advdev_homework_template/Nationalparks
mvn -s ../nexus_settings.xml clean package -Dmaven.test.skip=true

cd $HOME/advdev_homework_template/MLBParks
mvn -s ../nexus_settings.xml clean package -Dmaven.test.skip=true

cd $HOME/advdev_homework_template/ParksMap
mvn -s ../nexus_settings.xml clean package spring-boot:repackage -DskipTests -Dcom.redhat.xpaas.repo.redhatga


######    Grant the correct permissions to the Jenkins service account

#oc new-project $GUID-parks-dev --display-name "Shared Parks Dev"
#oc policy add-role-to-user admin ${USER} -n ${GUID}-parks-dev

#oc annotate namespace ${GUID}-parks-dev openshift.io/requester=${USER} --overwrite

######   Create ConfigMaps for configuration of the applications
oc project $GUID-parks-dev 

oc create configmap mongodb-configmap        --from-literal=DB_HOST=mongodb    --from-literal=DB_PORT=27017   --from-literal=DB_USERNAME=mongodb     --from-literal=DB_PASSWORD=mongodb   --from-literal=DB_NAME=parks   --from-literal=DB_REPLICASET=rs0

oc create configmap nationalparks-config     --from-literal=APPNAME="National Parks (Dev)"   

oc create configmap mlbparks-config     --from-literal=APPNAME="MLB Parks (Dev)"

oc create configmap parksmap-config     --from-literal=APPNAME="ParksMap (Dev)"


#####   Create a MongoDB database
#sudo docker pull registry.access.redhat.com/openshift3/mongodb-24-rhel7
sudo docker pull registry.access.redhat.com/rhscl/mongodb-26-rhel7
#oc new-app --name=mongodb  -e MONGODB_USER=mongodb MONGODB_PASSWORD=mongodb MONGODB_DATABASE=mongodb MONGODB_ADMIN_PASSWORD=mongodb registry.access.redhat.com/rhscl/mongodb-26-rhel7
#oc new-app --name=mongodb -e MONGODB_USER=mongodb -e MONGODB_PASSWORD=mongodb -e MONGODB_DATABASE=parks -e MONGODB_ADMIN_PASSWORD=mongodb    registry.access.redhat.com/rhscl/mongodb-26-rhel7
oc new-app mongodb-persistent --name=mongodb        
oc rollout pause dc/mongodb

oc set env dc/mongodb --from=configmap/mongodb-configmap
echo "apiVersion: "v1"
kind: "PersistentVolumeClaim"
metadata:
  name: "mongo-pvc"
spec:
  accessModes:
    - "ReadWriteOnce"
  resources:
    requests:
      storage: "2Gi"" | oc create -f -


oc set volume dc/mongodb --add --type=persistentVolumeClaim --name=mongo-pv --claim-name=mongo-pvc --mount-path=/data --containers=*
oc rollout resume dc/mongodb

# Now build all parks apps

oc new-build --binary=true --strategy=source --name=mlbparks jboss-eap70-openshift:1.7 
oc new-build --binary=true --strategy=source --name=nationalparks redhat-openjdk18-openshift:1.2
oc new-build --binary=true --strategy=source --name=parksmap redhat-openjdk18-openshift:1.2

#-t configmap --configmap-name=gogs
oc policy add-role-to-user view --serviceaccount=default


oc start-build mlbparks --from-file=$HOME/advdev_homework_template/MLBParks/target/mlbparks.war --follow
oc new-app $GUID-parks-dev/mlbparks:latest -e APPNAME="MLB Parks (Dev)" --name=mlbparks 

oc start-build nationalparks --from-file=$HOME/advdev_homework_template/Nationalparks/target/nationalparks.jar --follow
oc new-app $GUID-parks-dev/nationalparks:latest -e APPNAME="National Parks (Dev)" --name=nationalparks  


oc start-build parksmap --from-file=$HOME/advdev_homework_template/ParksMap/target/parksmap.jar --follow
oc new-app $GUID-parks-dev/parksmap:latest -e APPNAME="ParksMap (Dev)" --name=parksmap  


#oc new-app $GUID-parks-dev/mlbparks:0.0-0 -t configmap --configmap-name=mlbparks-config --name=mlbparks --allow-missing-imagestream-tags=true
#oc new-app $GUID-parks-dev/nationalparks:0.0-0 -t configmap --configmap-name=nationalparks-config --name=nationalparks --allow-missing-imagestream-tags=true
#oc new-app $GUID-parks-dev/parksmap:0.0-0 -t configmap --configmap-name=parksmap-config --name=parksmap --allow-missing-imagestream-tags=true


oc set triggers dc/mlbparks --remove-all
oc set triggers dc/nationalparks --remove-all
oc set triggers dc/parksmap --remove-all


####       Expose and label the services properly (parksmap-backend)

oc expose dc mlbparks --port 8080
oc expose dc nationalparks --port 8080
oc expose dc parksmap --port 8080

oc expose svc mlbparks -l type=parksmap-backend
oc expose svc nationalparks  -l type=parksmap-backend
oc expose svc parksmap  -l type=parksmap-backend


######     Set up liveness and readiness probes

oc set probe dc/mlbparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
oc set probe dc/mlbparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/

oc set probe dc/nationalparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/

oc set probe dc/nationalparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/


oc set probe dc/parksmap --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
oc set probe dc/parksmap --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/


#oc create configmap mlbparks-config --from-literal="application-db.properties=Placeholder"
#oc create configmap nationalparks-config --from-literal="application-db.properties=Placeholder"


#oc create configmap nationalparks-config     --from-literal=APPNAME="National Parks (Dev)"
######   Configure the deployment configurations using the ConfigMaps

oc set env dc/nationalparks --from=configmap/nationalparks-config
oc set env dc/nationalparks --from=configmap/mongodb-configmap

#oc create configmap mlbparks-config     --from-literal=APPNAME="MLB Parks (Dev)"
oc set env dc/mlbparks --from=configmap/mlbparks-config
oc set env dc/mlbparks --from=configmap/mongodb-configmap
#oc create configmap parksmap-config     --from-literal=APPNAME="ParksMap (Dev)"


oc set env dc/parksmap --from=configmap/parksmap-config




oc patch dc/mlbparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: mlbparks, command: ['curl -XGET http://localhost:8080/ws/data/load/']}}}}}"
oc patch dc/nationalparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: nationalparks, command: ['curl -XGET http://localhost:8080/ws/data/load/']}}}}}"
##### Set deploymenth  hooks
    
oc set deployment-hook dc/nationalparks --post     -- curl -s http://nationalparks:8080/ws/data/load/

oc rollout latest dc/nationalparks -n $GUID-parks-dev

oc set deployment-hook dc/mlbparks --post     -- curl -s http://mlbparks:8080/ws/data/load/

oc rollout latest dc/mlbparks -n $GUID-parks-dev
