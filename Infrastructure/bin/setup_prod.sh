#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi
#echo "Skipping production for now"
#exit

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.


####     Grant the correct permissions to the Jenkins service account

####     Grant the correct permissions to pull images from the development project

####     Grant the correct permissions for the ParksMap application to read back-end services (see the associated README file)

#oc new-project $GUID-parks-prod --display-name "Shared Parks Prod"
oc project $GUID-parks-prod 
oc policy add-role-to-user admin ${USER} -n ${GUID}-parks-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:${GUID}-parks-prod -n ${GUID}-parks-dev
oc policy add-role-to-user edit system:serviceaccount:${GUID}-jenkins:jenkins -n ${GUID}-parks-prod



#oc annotate namespace ${GUID}-parks-dev openshift.io/requester=${USER} --overwrite

######     Set up a replicated MongoDB database via StatefulSet with at least three replicas


#oc create configmap mongodb-prod-configmap        --from-literal=DB_HOST=mongodb-p    --from-literal=DB_PORT=27017   --from-literal=DB_USERNAME=mongodb-p     --from-literal=DB_PASSWORD=mongodb-p   --from-literal=DB_NAME=parks-prod   --from-literal=DB_REPLICASET=rs3
# Config MongoDB configmap
oc -n ${GUID}-parks-prod create configmap park-prd-conf \
       --from-literal=DB_REPLICASET=rs0 \
       --from-literal=DB_HOST=mongodb \
       --from-literal=DB_PORT=27017 \
       --from-literal=DB_USERNAME=mongodb \
       --from-literal=DB_PASSWORD=mongodb \
       --from-literal=DB_NAME=parks
       
       
oc create configmap b-nationalparks-config     --from-literal=APPNAME="National Parks (Blue)"

oc create configmap b-mlbparks-config     --from-literal=APPNAME="MLB Parks (Blue)"

oc create configmap b-parksmap-config     --from-literal=APPNAME="ParksMap (Blue)"

oc create configmap g-nationalparks-config     --from-literal=APPNAME="National Parks (Green)"

oc create configmap g-mlbparks-config     --from-literal=APPNAME="MLB Parks (Green)"

oc create configmap g-parksmap-config     --from-literal=APPNAME="ParksMap (Green)"


#sudo docker pull registry.access.redhat.com/openshift3/mongodb-24-rhel7
#sudo docker pull registry.access.redhat.com/rhscl/mongodb-26-rhel7
#oc new-app --name=mongodb  -e MONGODB_USER=mongodb MONGODB_PASSWORD=mongodb MONGODB_DATABASE=mongodb MONGODB_ADMIN_PASSWORD=mongodb registry.access.redhat.com/rhscl/mongodb-26-rhel7
#oc new-app --name=mongodb -e MONGODB_USER=mongodb -e MONGODB_PASSWORD=mongodb -e MONGODB_DATABASE=parks -e MONGODB_ADMIN_PASSWORD=mongodb    registry.access.redhat.com/rhs
#cl/mongodb-26-rhel7
#oc new-app mongodb-persistent --name=mongodb-p
#oc rollout pause dc/mongodb


echo 'kind: Service
apiVersion: v1
metadata:
  name: "mongodb-internal"
  labels:
    name: "mongodb"
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
spec:
  clusterIP: None
  ports:
    - name: mongodb
      port: 27017
  selector:
    name: "mongodb"' | oc create -n ${GUID}-parks-prod -f -

echo 'kind: Service
apiVersion: v1
metadata:
  name: "mongodb"
  labels:
    name: "mongodb"
spec:
  ports:
    - name: mongodb
      port: 27017
  selector:
    name: "mongodb"' | oc create -n ${GUID}-parks-prod -f -
    
    

oc set env dc/mongodb-p --from=configmap/park-prd-conf
echo "apiVersion: "v1"
kind: "PersistentVolumeClaim"
metadata:
  name: "mongo-pvc-prod"
spec:
  accessModes:
    - "ReadWriteOnce"
  resources:
    requests:
      storage: "2Gi"" | oc create -f -


oc set volume dc/mongodb-p --add --type=persistentVolumeClaim --name=mongo-pv --claim-name=mongo-pvc-prod --mount-path=/data --containers=*
oc rollout resume dc/mongodb-p

while : ; do
    oc get pod -n ${GUID}-parks-prod | grep -v deploy | grep "1/1"
    echo "Checking if MongoDB is Ready..."
    if [ $? == "1" ] 
      then 
      echo "Wait 10 seconds..."
        sleep 10
      else 
        break 
    fi
done


# Now build all parks apps

oc new-build --binary=true --strategy=source --name=b-mlbparks jboss-eap70-openshift:1.7
oc new-build --binary=true --strategy=source --name=b-nationalparks redhat-openjdk18-openshift:1.2
oc new-build --binary=true --strategy=source --name=b-parksmap redhat-openjdk18-openshift:1.2

oc new-build --binary=true --strategy=source --name=g-mlbparks jboss-eap70-openshift:1.7
oc new-build --binary=true --strategy=source --name=g-nationalparks redhat-openjdk18-openshift:1.2
oc new-build --binary=true --strategy=source --name=g-parksmap redhat-openjdk18-openshift:1.2


#-t configmap --configmap-name=gogs
oc policy add-role-to-user view --serviceaccount=default

######   Set up blue and green instances for each of the three microservices


#oc start-build b-mlbparks --from-file=MLBParks/target/mlbparks.war --follow
#oc new-app $GUID-parks-prod/b-mlbparks:latest -e APPNAME="MLB Parks (Blue)" --name=b-mlbparks
#oc start-build g-mlbparks --from-file=$HOME/advdev_homework_template/MLBParks/target/mlbparks.war --follow
#oc new-app $GUID-parks-prod/g-mlbparks:latest -e APPNAME="MLB Parks (Green)" --name=g-mlbparks

#oc start-build b-nationalparks --from-file=Nationalparks/target/nationalparks.jar --follow
#oc new-app $GUID-parks-prod/b-nationalparks:latest -e APPNAME="National Parks (Blue)" --name=b-nationalparks
#oc start-build g-nationalparks --from-file=Nationalparks/target/nationalparks.jar --follow
#oc new-app $GUID-parks-prod/g-nationalparks:latest -e APPNAME="National Parks (Green)" --name=g-nationalparks


#oc start-build b-parksmap --from-file=ParksMap/target/parksmap.jar --follow
#oc new-app $GUID-parks-prod/b-parksmap:latest -e APPNAME="ParksMap (Blue)" --name=b-parksmap
#oc start-build g-parksmap --from-file=ParksMap/target/parksmap.jar --follow
#oc new-app $GUID-parks-prod/g-parksmap:latest -e APPNAME="ParksMap (Green)" --name=g-parksmap




oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=b-mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=b-nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=b-parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=g-mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=g-nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=g-parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod



#oc new-app $GUID-parks-dev/mlbparks:0.0-0 -t configmap --configmap-name=mlbparks-config --name=mlbparks --allow-missing-imagestream-tags=true
#oc new-app $GUID-parks-dev/nationalparks:0.0-0 -t configmap --configmap-name=nationalparks-config --name=nationalparks --allow-missing-imagestream-tags=true
#oc new-app $GUID-parks-dev/parksmap:0.0-0 -t configmap --configmap-name=parksmap-config --name=parksmap --allow-missing-imagestream-tags=true


oc set triggers dc/b-mlbparks --remove-all
oc set triggers dc/b-nationalparks --remove-all
oc set triggers dc/b-mlbparks --remove-all
oc set triggers dc/g-nationalparks --remove-all
oc set triggers dc/g-parksmap --remove-all
oc set triggers dc/g-parksmap --remove-all


#oc expose dc b-mlbparks --port 8080
#oc expose dc b-nationalparks --port 8080
#oc expose dc b-parksmap --port 8080
oc expose dc g-mlbparks --port 8080
oc expose dc g-nationalparks --port 8080
oc expose dc g-parksmap --port 8080

#####   Make the Green service active initially to guarantee a Blue rollout upon the first pipeline run

oc expose svc b-mlbparks -l type=parksmap-backend-standby
oc expose svc b-nationalparks  -l type=parksmap-backend-standby
oc expose svc b-parksmap  -l type=parksmap-backend-standby
oc expose svc g-mlbparks -l type=parksmap-backend
oc expose svc g-nationalparks  -l type=parksmap-backend
oc expose svc g-parksmap  -l type=parksmap-backend


oc set probe dc/b-mlbparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
oc set probe dc/b-mlbparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/

oc set probe dc/b-nationalparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
oc set probe dc/b-nationalparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/


oc set probe dc/b-parksmap --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
oc set probe dc/b-parksmap --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/

oc set probe dc/g-mlbparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
oc set probe dc/g-mlbparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/

oc set probe dc/g-nationalparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
oc set probe dc/g-nationalparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/


oc set probe dc/g-parksmap --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
oc set probe dc/g-parksmap --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/

#oc create configmap mlbparks-config --from-literal="application-db.properties=Placeholder"
#oc create configmap nationalparks-config --from-literal="application-db.properties=Placeholder"


#oc create configmap nationalparks-config     --from-literal=APPNAME="National Parks (Dev)"


oc set env dc/b-nationalparks --from=configmap/b-nationalparks-config
oc set env dc/b-nationalparks --from=configmap/mongodb-prod-configmap

oc set env dc/g-nationalparks --from=configmap/g-nationalparks-config
oc set env dc/g-nationalparks --from=configmap/mongodb-prod-configmap

#oc create configmap mlbparks-config     --from-literal=APPNAME="MLB Parks (Dev)"
oc set env dc/b-mlbparks --from=configmap/b-mlbparks-config
oc set env dc/b-mlbparks --from=configmap/mongodb-prod-configmap

oc set env dc/g-mlbparks --from=configmap/g-mlbparks-config
oc set env dc/g-mlbparks --from=configmap/mongodb-prod-configmap


#oc create configmap parksmap-config     --from-literal=APPNAME="ParksMap (Dev)"


oc set env dc/b-parksmap --from=configmap/b-parksmap-config


oc set env dc/g-parksmap --from=configmap/g-parksmap-config


oc patch dc/b-mlbparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: mlbparks, command: ['curl -XGET ht
tp://localhost:8080/ws/data/load/']}}}}}"
oc patch dc/b-nationalparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: nationalparks, command: ['cur
l -XGET http://localhost:8080/ws/data/load/']}}}}}"
oc patch dc/g-mlbparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: mlbparks, command: ['curl -XGET ht
tp://localhost:8080/ws/data/load/']}}}}}"
oc patch dc/g-nationalparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: nationalparks, command: ['cur
l -XGET http://localhost:8080/ws/data/load/']}}}}}"


#oc set deployment-hook dc/b-nationalparks --post     -- curl -s http://nationalparks:8080/ws/data/load/

#oc rollout latest dc/b-nationalparks -n 0254-parks-prod

#oc set deployment-hook dc/b-mlbparks --post     -- curl -s http://mlbparks:8080/ws/data/load/

#oc rollout latest dc/b-mlbparks -n 0254-parks-prod

oc set deployment-hook dc/g-nationalparks --post     -- curl -s http://nationalparks:8080/ws/data/load/
oc rollout latest dc/g-nationalparks -n $GUID-parks-prod

oc set deployment-hook dc/g-mlbparks --post     -- curl -s http://mlbparks:8080/ws/data/load/
oc rollout latest dc/g-mlbparks -n $GUID-parks-prod

