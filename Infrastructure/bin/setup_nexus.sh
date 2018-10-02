#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:
# while : ; do
#   echo "Checking if Nexus is Ready..."
#   oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
#   [[ "$?" == "1" ]] || break
#   echo "...no. Sleeping 10 seconds."
#   sleep 10
# done

# Ideally just calls a template
# oc new-app -f ../templates/nexus.yaml --param .....

oc project $GUID-nexus 
oc process -f Infrastructure/templates/nexus.yml -n ${GUID}-nexus -p GUID=${GUID} | oc create -n ${GUID}-nexus -f -
oc expose svc nexus3 -n ${GUID}-nexus
oc expose svc nexus-registry -n ${GUID}-nexus

while : ; do
    oc get pod -n ${GUID}-nexus | grep '\-1\-' | grep -v deploy | grep "1/1"
    if [ $? == "1" ] 
      then 
        sleep 10
      else 
        break 
    fi
done

curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh

chmod +x setup_nexus3.sh

sh setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n ${GUID}-nexus )
rm -f setup_nexus3.sh
exit


######## Create a new Nexus instance from docker.io/sonatype/nexus3:latest
echo "Create a new Nexus instance from template"

#oc new-project $GUID-nexus --display-name "Shared Nexus"
#oc policy add-role-to-user admin ${USER} -n ${GUID}-nexus

#oc annotate namespace ${GUID}-nexus openshift.io/requester=${USER} --overwrite



oc new-app sonatype/nexus3:latest
oc expose svc nexus3
oc rollout pause dc nexus3
echo 'Pause nexus deployment'
oc new-app -f ./Infrastructure/templates/nexus.yml -n "${GUID}-nexus"



#####    Configure Nexus appropriately for resources, deployment strategy, persistent volumes, and readiness and liveness probes

#oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'
#oc set resources dc nexus3 --limits=memory=2Gi --requests=memory=1Gi

#echo "apiVersion: v1
#kind: PersistentVolumeClaim
#metadata:
#  name: nexus-pvc
#spec:
#  accessModes:
#  - ReadWriteOnce
#  resources:
#    requests:
#      storage: 4Gi" | oc create -f -

#oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc
#oc set probe dc/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
#oc set probe dc/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/repository/maven-public/

#oc rollout resume dc nexus3

#sleep 350
while : ; do
 echo "Checking if Nexus is Ready..."
    oc get pod -n ${GUID}-nexus | grep '\-1\-' | grep -v deploy | grep "1/1"
    if [ $? == "1" ] 
      then 
      echo "...no. Sleeping 10 seconds."
        sleep 10
      else 
        break 
    fi
done


######     When Nexus is running, populate Nexus with the correct repositories

echo 'When Nexus is running, populate Nexus with the correct repositories'
curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}')
rm setup_nexus3.sh
echo "./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}')"


#######    Expose the container registry

oc expose dc nexus3 --port=5000 --name=nexus-registry
oc create route edge nexus-registry --service=nexus-registry --port=5000



oc get routes -n $GUID-nexus
