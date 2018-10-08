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

sleep 300

####     Grant the correct permissions to the Jenkins service account

####     Grant the correct permissions to pull images from the development project

####     Grant the correct permissions for the ParksMap application to read back-end services (see the associated README file)

#oc new-project $GUID-parks-prod --display-name "Shared Parks Prod"
oc project $GUID-parks-prod 
oc policy add-role-to-user view --serviceaccount=default -n $GUID-parks-prod
oc policy add-role-to-group system:image-puller system:serviceaccounts:$GUID-parks-prod -n $GUID-parks-dev
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n $GUID-parks-prod
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n $GUID-parks-prod


echo 'MONGODB creation for prod'


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


echo '*********************************************************************************'
echo 'Rollout started'
echo '*********************************************************************************'


echo 'Create Prod configmaps'

oc create configmap mlbparks-blue-config --from-env-file=./Infrastructure/templates/b-MLBParks -n ${GUID}-parks-prod
oc create configmap nationalparks-blue-config --from-env-file=./Infrastructure/templates/b-NationalParks -n ${GUID}-parks-prod
oc create configmap parksmap-blue-config --from-env-file=./Infrastructure/templates/b-ParksMap -n ${GUID}-parks-prod
oc create configmap mlbparks-green-config --from-env-file=./Infrastructure/templates/g-MLBParks -n ${GUID}-parks-prod
oc create configmap nationalparks-green-config --from-env-file=./Infrastructure/templates/g-NationalParks -n ${GUID}-parks-prod
oc create configmap parksmap-green-config --from-env-file=./Infrastructure/templates/g-ParksMap -n ${GUID}-parks-prod


echo 'Create Blue apps'

oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=b-mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=b-nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=b-parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

oc set triggers dc/b-mlbparks --remove-all -n ${GUID}-parks-prod
oc set triggers dc/b-nationalparks --remove-all -n ${GUID}-parks-prod
oc set triggers dc/b-parksmap --remove-all -n ${GUID}-parks-prod


echo 'Set blue apps env'


oc set env dc/b-mlbparks --from=configmap/mlbparks-blue-config -n ${GUID}-parks-prod
oc set env dc/b-nationalparks --from=configmap/nationalparks-blue-config -n ${GUID}-parks-prod
oc set env dc/b-parksmap --from=configmap/parksmap-blue-config -n ${GUID}-parks-prod


echo 'Set green apps'

oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=g-mlbparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=g-nationalparks --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=g-parksmap --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod


echo 'Set triggers and env for green apps'

oc set triggers dc/g-mlbparks --remove-all -n ${GUID}-parks-prod
oc set triggers dc/g-nationalparks --remove-all -n ${GUID}-parks-prod
oc set triggers dc/g-parksmap --remove-all -n ${GUID}-parks-prod

oc set env dc/g-mlbparks --from=configmap/mlbparks-green-config -n ${GUID}-parks-prod
oc set env dc/g-nationalparks --from=configmap/nationalparks-green-config -n ${GUID}-parks-prod
oc set env dc/g-parksmap --from=configmap/parksmap-green-config -n ${GUID}-parks-prod

echo 'Expose dcs'

oc expose dc g-mlbparks --port 8080 -n ${GUID}-parks-prod
oc expose dc g-nationalparks --port 8080 -n ${GUID}-parks-prod
oc expose dc g-parksmap --port 8080 -n ${GUID}-parks-prod

oc expose dc b-mlbparks --port 8080 -n ${GUID}-parks-prod
oc expose dc b-nationalparks --port 8080 -n ${GUID}-parks-prod
oc expose dc b-parksmap --port 8080 -n ${GUID}-parks-prod

echo 'Expose svc'

oc expose svc g-mlbparks --name mlbparks -n ${GUID}-parks-prod --labels="type=parksmap-backend"
oc expose svc g-nationalparks --name nationalparks -n ${GUID}-parks-prod --labels="type=parksmap-backend"
oc expose svc g-parksmap --name parksmap -n ${GUID}-parks-prod


echo 'Set deployment hooks'

oc set deployment-hook dc/g-mlbparks  -n ${GUID}-parks-prod --post -c g-mlbparks --failure-policy=ignore -- curl http://g-mlbparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/g-nationalparks  -n ${GUID}-parks-prod --post -c g-nationalparks --failure-policy=ignore -- curl http://g-nationalparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/g-parksmap  -n ${GUID}-parks-prod --post -c g-parksmap --failure-policy=ignore -- curl http://g-mlbparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/

oc set deployment-hook dc/b-mlbparks  -n ${GUID}-parks-prod --post -c b-mlbparks --failure-policy=ignore -- curl http://b-mlbparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/b-nationalparks  -n ${GUID}-parks-prod --post -c b-nationalparks --failure-policy=ignore -- curl http://b-nationalparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/b-parksmap  -n ${GUID}-parks-prod --post -c b-parksmap --failure-policy=ignore -- curl http://b-mlbparks.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/



echo 'Set probes'


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

echo '*********************************************************************************'
echo 'Rollout terminated'
echo '*********************************************************************************'
