Fixed 400 when trying curl command by updating the Cloud Run URL in: 
/home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/proxies/hello-world-proxy/apiproxy/targets/default.xml

the url in : 
<HTTPTargetConnection>
    <URL>https://cloudrunurlPLACEHOLDER.REGION-PLACEHOLDER.run.app</URL> 
was wrong and it had the url from the previous GCP project. 

Pending: Test: rebuild zip and steps until test curl. 