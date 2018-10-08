#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi
#echo "Skipping production for now"
#exit
#sleep 2000
#echo '....sleep 2000'

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.


####     Grant the correct permissions to the Jenkins service account

####     Grant the correct permissions to pull images from the development project

####     Grant the correct permissions for the ParksMap application to read back-end services (see the associated README file)

#oc new-project $GUID-parks-prod --display-name "Shared Parks Prod"
oc project $GUID-parks-prod 
oc policy add-role-to-user view --serviceaccount=default -n $GUID-parks-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:$GUID-parks-prod -n $GUID-parks-dev
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n $GUID-parks-prod
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n $GUID-parks-prod



#oc annotate namespace ${GUID}-parks-dev openshift.io/requester=${USER} --overwrite

######     Set up a replicated MongoDB database via StatefulSet with at least three replicas


#oc create configmap mongodb-prod-configmap        --from-literal=DB_HOST=mongodb-p    --from-literal=DB_PORT=27017   --from-literal=DB_USERNAME=mongodb-p     --from-literal=DB_PASSWORD=mongodb-p   --from-literal=DB_NAME=parks-prod   --from-literal=DB_REPLICASET=rs3
# Config MongoDB configmap
#oc -n ${GUID}-parks-prod create configmap park-prd-conf \
#       --from-literal=DB_REPLICASET=rs0 \
#       --from-literal=DB_HOST=mongodb \
#       --from-literal=DB_PORT=27017 \
#       --from-literal=DB_USERNAME=mongodb \
#       --from-literal=DB_PASSWORD=mongodb \
#       --from-literal=DB_NAME=parks
       
       
#oc create configmap b-nationalparks-config     --from-literal=APPNAME="National Parks (Blue)"
#oc create configmap b-mlbparks-config     --from-literal=APPNAME="MLB Parks (Blue)"
#oc create configmap b-parksmap-config     --from-literal=APPNAME="ParksMap (Blue)"
#oc create configmap g-nationalparks-config     --from-literal=APPNAME="National Parks (Green)"
#oc create configmap g-mlbparks-config     --from-literal=APPNAME="MLB Parks (Green)"
#oc create configmap g-parksmap-config     --from-literal=APPNAME="ParksMap (Green)"

#echo '*********************************************************************************'
#echo 'Config map created'
#echo '*********************************************************************************'
#sudo docker pull registry.access.redhat.com/openshift3/mongodb-24-rhel7
#sudo docker pull registry.access.redhat.com/rhscl/mongodb-26-rhel7
#oc new-app --name=mongodb  -e MONGODB_USER=mongodb MONGODB_PASSWORD=mongodb MONGODB_DATABASE=mongodb MONGODB_ADMIN_PASSWORD=mongodb registry.access.redhat.com/rhscl/mongodb-26-rhel7
#oc new-app --name=mongodb -e MONGODB_USER=mongodb -e MONGODB_PASSWORD=mongodb -e MONGODB_DATABASE=parks -e MONGODB_ADMIN_PASSWORD=mongodb    registry.access.redhat.com/rhs
#cl/mongodb-26-rhel7
#oc new-app mongodb-persistent --name=mongodb-p
#oc rollout pause dc/mongodb


echo 'MONGODB creation for prod'

#echo 'kind: Service
#apiVersion: v1
#metadata:
#  name: "mongodb-internal"
#  labels:
#    name: "mongodb"
#  annotations:
#    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
#spec:
#  clusterIP: None
#  ports:
#    - name: mongodb
#      port: 27017
#  selector:
#    name: "mongodb"' | oc create -n ${GUID}-parks-prod -f -

#echo 'kind: Service
#apiVersion: v1
#metadata:
#  name: "mongodb"
#  labels:
#    name: "mongodb"
#spec:
#  ports:
#    - name: mongodb
#      port: 27017
#  selector:
#    name: "mongodb"' | oc create -n ${GUID}-parks-prod -f -

oc create -f ./Infrastructure/templates/mongodb-prod.yml -n ${GUID}-parks-prod

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

#oc new-build --binary=true --strategy=source --name=b-mlbparks jboss-eap70-openshift:1.7
#oc new-build --binary=true --strategy=source --name=b-nationalparks redhat-openjdk18-openshift:1.2
#oc new-build --binary=true --strategy=source --name=b-parksmap redhat-openjdk18-openshift:1.2

#oc new-build --binary=true --strategy=source --name=g-mlbparks jboss-eap70-openshift:1.7
#oc new-build --binary=true --strategy=source --name=g-nationalparks redhat-openjdk18-openshift:1.2
#oc new-build --binary=true --strategy=source --name=g-parksmap redhat-openjdk18-openshift:1.2



#echo '*********************************************************************************'
#echo 'Build created'
#echo '*********************************************************************************'


#-t configmap --configmap-name=gogs
#oc policy add-role-to-user view --serviceaccount=default

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




#oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=b-mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
#oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=b-nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
#oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=b-parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

#oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=g-mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
#oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=g-nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
#oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=g-parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

#oc rollout pause dc/b-mlbparks
#oc rollout pause dc/b-nationalparks
#oc rollout pause dc/b-parksmap
#oc rollout pause dc/g-mlbparks
#oc rollout pause dc/g-nationalparks
#oc rollout pause dc/g-parksmap


echo '*********************************************************************************'
echo 'Apps created'
echo '*********************************************************************************'


#oc new-app $GUID-parks-dev/mlbparks:0.0-0 -t configmap --configmap-name=mlbparks-config --name=mlbparks --allow-missing-imagestream-tags=true
#oc new-app $GUID-parks-dev/nationalparks:0.0-0 -t configmap --configmap-name=nationalparks-config --name=nationalparks --allow-missing-imagestream-tags=true
#oc new-app $GUID-parks-dev/parksmap:0.0-0 -t configmap --configmap-name=parksmap-config --name=parksmap --allow-missing-imagestream-tags=true


#while : ; do
#    oc get pod -n ${GUID}-parks-prod | grep -v deploy | grep "1/1"
#    echo "Checking if Apps are Ready..."
#    if [ $? == "1" ] 
#      then 
#      echo "Wait 10 seconds..."
#        sleep 10
#      else 
#        break 
#    fi
#done


#oc set triggers dc/b-mlbparks --remove-all
#oc set triggers dc/b-nationalparks --remove-all
#oc set triggers dc/b-mlbparks --remove-all
#oc set triggers dc/g-nationalparks --remove-all
#oc set triggers dc/g-parksmap --remove-all
#oc set triggers dc/g-parksmap --remove-all


#echo '*********************************************************************************'
#echo 'Triggers created'
#echo '*********************************************************************************'

#oc expose dc b-mlbparks --port 8080
#oc expose dc b-nationalparks --port 8080
#oc expose dc b-parksmap --port 8080
#oc expose dc g-mlbparks --port 8080
#oc expose dc g-nationalparks --port 8080
#oc expose dc g-parksmap --port 8080

#####   Make the Green service active initially to guarantee a Blue rollout upon the first pipeline run

#oc expose svc b-mlbparks -l type=parksmap-backend-standby
#oc expose svc b-nationalparks  -l type=parksmap-backend-standby
#oc expose svc b-parksmap  -l type=parksmap-backend-standby
#oc expose svc g-mlbparks -l type=parksmap-backend
#oc expose svc g-nationalparks  -l type=parksmap-backend
#oc expose svc g-parksmap  -l type=parksmap-backend


#echo '*********************************************************************************'
#echo 'Expose created'
#echo '*********************************************************************************'

#oc set probe dc/b-mlbparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
#oc set probe dc/b-mlbparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/

#oc set probe dc/b-nationalparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
#oc set probe dc/b-nationalparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/


#oc set probe dc/b-parksmap --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
#oc set probe dc/b-parksmap --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/

#oc set probe dc/g-mlbparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
#oc set probe dc/g-mlbparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/

#oc set probe dc/g-nationalparks --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
#oc set probe dc/g-nationalparks --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/


#oc set probe dc/g-parksmap --readiness     --initial-delay-seconds 30 --failure-threshold 3   --get-url=http://:8080/ws/healthz/
#oc set probe dc/g-parksmap --liveness      --initial-delay-seconds 30 --failure-threshold 3     --get-url=http://:8080/ws/healthz/



#echo '*********************************************************************************'
#echo 'Probe created'
#echo '*********************************************************************************'

#oc create configmap mlbparks-config --from-literal="application-db.properties=Placeholder"
#oc create configmap nationalparks-config --from-literal="application-db.properties=Placeholder"


#oc create configmap nationalparks-config     --from-literal=APPNAME="National Parks (Dev)"


#oc set env dc/b-nationalparks --from=configmap/b-nationalparks-config
#oc set env dc/b-nationalparks --from=configmap/park-prd-conf

#oc set env dc/g-nationalparks --from=configmap/g-nationalparks-config
#oc set env dc/g-nationalparks --from=configmap/park-prd-conf

#oc create configmap mlbparks-config     --from-literal=APPNAME="MLB Parks (Dev)"
#oc set env dc/b-mlbparks --from=configmap/b-mlbparks-config
#oc set env dc/b-mlbparks --from=configmap/park-prd-conf

#oc set env dc/g-mlbparks --from=configmap/g-mlbparks-config
#oc set env dc/g-mlbparks --from=configmap/park-prd-conf

#oc create configmap parksmap-config     --from-literal=APPNAME="ParksMap (Dev)"


#oc set env dc/b-parksmap --from=configmap/b-parksmap-config


#oc set env dc/g-parksmap --from=configmap/g-parksmap-config


#echo '*********************************************************************************'
#echo 'confi map env created'
#echo '*********************************************************************************'


#oc patch dc/b-mlbparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: b-mlbparks, command: ['curl -XGET ht
#tp://localhost:8080/ws/data/load/']}}, timeoutSeconds: 6000}}}"
#oc patch dc/b-nationalparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: b-nationalparks, command: ['cur
#l -XGET http://localhost:8080/ws/data/load/']}}, timeoutSeconds: 6000}}}"
#oc patch dc/b-parksmap --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: b-parksmap, command: ['cur
#l -XGET http://localhost:8080/ws/data/load/']}}, timeoutSeconds: 6000}}}"
#oc patch dc/g-mlbparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: g-mlbparks, command: ['curl -XGET ht
#tp://localhost:8080/ws/data/load/']}}, timeoutSeconds: 6000}}}"
#oc patch dc/g-nationalparks --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: g-nationalparks, command: ['cur
#l -XGET http://localhost:8080/ws/data/load/']}}, timeoutSeconds: 6000}}}"
#oc patch dc/g-parksmap --patch "spec: { strategy: {type: Rolling, rollingParams: {post: {failurePolicy: Ignore, execNewPod: {containerName: g-parksmap, command: ['cur
#l -XGET http://localhost:8080/ws/data/load/']}}, timeoutSeconds: 6000}}}"


#echo '*********************************************************************************'
#echo 'Patch created'
#echo '*********************************************************************************'


#oc set deployment-hook dc/b-nationalparks --post     -- curl -s http://nationalparks:8080/ws/data/load/

#oc rollout latest dc/b-nationalparks -n 0254-parks-prod

#oc set deployment-hook dc/b-mlbparks --post     -- curl -s http://mlbparks:8080/ws/data/load/

#oc rollout latest dc/b-mlbparks -n 0254-parks-prod


echo '*********************************************************************************'
echo 'Rollout started'
echo '*********************************************************************************'

#sleep 1000
#echo '....sleep 1000'


#oc set deployment-hook dc/g-nationalparks --post     -- curl -s http://nationalparks:8080/ws/data/load/
#oc rollout latest dc/g-nationalparks -n $GUID-parks-prod

#oc set deployment-hook dc/g-mlbparks --post     -- curl -s http://mlbparks:8080/ws/data/load/
#oc rollout latest dc/g-mlbparks -n $GUID-parks-prod

#oc set deployment-hook dc/g-nationalparks  -n ${GUID}-parks-prod --post -c nationalparks --failure-policy=abort -- curl http://$(oc get route nationalparks -n ${GUID}-parks-prod -o jsonpath='{ .spec.host }')/ws/data/load/
#oc set deployment-hook dc/g-mlbparks  -n ${GUID}-parks-prod --post -c mlbparks --failure-policy=abort -- curl http://$(oc get route mlbparks -n ${GUID}-parks-prod -o jsonpath='{ .spec.host }')/ws/data/load/
#oc set deployment-hook dc/g-parksmap  -n ${GUID}-parks-prod --post -c parksmap --failure-policy=abort -- curl http://$(oc get route parksmap -n ${GUID}-parks-prod -o jsonpath='{ .spec.host }')/ws/data/load/
#oc set deployment-hook dc/b-nationalparks  -n ${GUID}-parks-prod --post -c nationalparks --failure-policy=abort -- curl http://$(oc get route nationalparks -n ${GUID}-parks-prod -o jsonpath='{ .spec.host }')/ws/data/load/
#oc set deployment-hook dc/b-mlbparks  -n ${GUID}-parks-prod --post -c mlbparks --failure-policy=abort -- curl http://$(oc get route mlbparks -n ${GUID}-parks-prod -o jsonpath='{ .spec.host }')/ws/data/load/
#oc set deployment-hook dc/b-parksmap  -n ${GUID}-parks-prod --post -c parksmap --failure-policy=abort -- curl http://$(oc get route parksmap -n ${GUID}-parks-prod -o jsonpath='{ .spec.host }')/ws/data/load/


#sleep 1000

#oc rollout resume dc/b-nationalparks -n $GUID-parks-dev
#oc rollout resume dc/g-nationalparks -n $GUID-parks-dev

#sleep 1000

#oc rollout resume dc/b-mlbparks -n $GUID-parks-dev
#oc rollout resume dc/g-mlbparks -n $GUID-parks-dev

#sleep 1000

#oc rollout resume dc/b-parksmap -n $GUID-parks-dev
#oc rollout resume dc/g-parksmap -n $GUID-parks-dev

#sleep 1000

#oc rollout latest dc/b-mlbparks  -n $GUID-parks-prod
#oc rollout latest dc/b-nationalparks  -n $GUID-parks-prod
#oc rollout latest dc/b-parksmap  -n $GUID-parks-prod

#oc rollout latest dc/g-mlbparks  -n $GUID-parks-prod
#oc rollout latest dc/g-nationalparks  -n $GUID-parks-prod
#oc rollout latest dc/g-parksmap  -n $GUID-parks-prod


echo  "Here starts"


#configmaps
oc create configmap mlbparks-blue-config --from-env-file=./Infrastructure/templates/b-MLBParks -n ${GUID}-parks-prod
oc create configmap nationalparks-blue-config --from-env-file=./Infrastructure/templates/b-NationalParks -n ${GUID}-parks-prod
oc create configmap parksmap-blue-config --from-env-file=./Infrastructure/templates/b-ParksMap -n ${GUID}-parks-prod
oc create configmap mlbparks-green-config --from-env-file=./Infrastructure/templates/g-MLBParks -n ${GUID}-parks-prod
oc create configmap nationalparks-green-config --from-env-file=./Infrastructure/templates/g-NationalParks -n ${GUID}-parks-prod
oc create configmap parksmap-green-config --from-env-file=./Infrastructure/templates/g-ParksMap -n ${GUID}-parks-prod

#blue services

oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=b-mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=b-nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=b-parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

oc set triggers dc/b-mlbparks --remove-all -n ${GUID}-parks-prod
oc set triggers dc/b-nationalparks --remove-all -n ${GUID}-parks-prod
oc set triggers dc/b-parksmap --remove-all -n ${GUID}-parks-prod

oc set env dc/b-mlbparks --from=configmap/mlbparks-blue-config -n ${GUID}-parks-prod
oc set env dc/b-nationalparks --from=configmap/nationalparks-blue-config -n ${GUID}-parks-prod
oc set env dc/b-parksmap --from=configmap/parksmap-blue-config -n ${GUID}-parks-prod

#green services

oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=g-mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=g-nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=g-parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

oc set triggers dc/g-mlbparks --remove-all -n ${GUID}-parks-prod
oc set triggers dc/g-nationalparks --remove-all -n ${GUID}-parks-prod
oc set triggers dc/g-parksmap --remove-all -n ${GUID}-parks-prod

oc set env dc/g-mlbparks --from=configmap/mlbparks-green-config -n ${GUID}-parks-prod
oc set env dc/g-nationalparks --from=configmap/nationalparks-green-config -n ${GUID}-parks-prod
oc set env dc/g-parksmap --from=configmap/parksmap-green-config -n ${GUID}-parks-prod

#expose deployment config for all services

oc expose dc g-mlbparks --port 8080 -n ${GUID}-parks-prod
oc expose dc g-nationalparks --port 8080 -n ${GUID}-parks-prod
oc expose dc g-parksmap --port 8080 -n ${GUID}-parks-prod

oc expose dc b-mlbparks --port 8080 -n ${GUID}-parks-prod
oc expose dc b-nationalparks --port 8080 -n ${GUID}-parks-prod
oc expose dc b-parksmap --port 8080 -n ${GUID}-parks-prod

#expose green service

oc expose svc g-mlbparks --name mlbparks -n ${GUID}-parks-prod --labels="type=parksmap-backend"
oc expose svc g-nationalparks --name nationalparks -n ${GUID}-parks-prod --labels="type=parksmap-backend"
oc expose svc g-parksmap --name parksmap -n ${GUID}-parks-prod

oc set deployment-hook dc/g-mlbparks  -n ${GUID}-parks-prod --post -c g-mlbparks --failure-policy=ignore -- curl http://g-mlbparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/g-nationalparks  -n ${GUID}-parks-prod --post -c g-nationalparks --failure-policy=ignore -- curl http://g-nationalparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/g-parksmap  -n ${GUID}-parks-prod --post -c g-parksmap --failure-policy=ignore -- curl http://g-mlbparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/

oc set deployment-hook dc/b-mlbparks  -n ${GUID}-parks-prod --post -c b-mlbparks --failure-policy=ignore -- curl http://b-mlbparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/b-nationalparks  -n ${GUID}-parks-prod --post -c b-nationalparks --failure-policy=ignore -- curl http://b-nationalparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/b-parksmap  -n ${GUID}-parks-prod --post -c b-parksmap --failure-policy=ignore -- curl http://b-mlbparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/

oc set probe dc/b-parksmap --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/b-parksmap --readiness --failure-threshold 5 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/b-mlbparks --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/b-mlbparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/b-nationalparks --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/b-nationalparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/g-parksmap --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/g-parksmap --readiness --failure-threshold 5 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/g-mlbparks --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/g-mlbparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/g-nationalparks --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/g-nationalparks --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod

#Deploy latest 

#oc rollout latest dc/b-mlbparks  -n $GUID-parks-prod
#oc rollout latest dc/b-nationalparks  -n $GUID-parks-prod
#oc rollout latest dc/b-parksmap  -n $GUID-parks-prod

#oc rollout latest dc/g-mlbparks  -n $GUID-parks-prod
#oc rollout latest dc/g-nationalparks  -n $GUID-parks-prod
#oc rollout latest dc/g-parksmap  -n $GUID-parks-prod

echo '*********************************************************************************'
echo 'Rollout terminated'
echo '*********************************************************************************'
