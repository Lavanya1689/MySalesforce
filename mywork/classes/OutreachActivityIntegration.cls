public with sharing class OutreachActivityIntegration implements Schedulable{
    static List<SObject> outreachActivities;
    static String accessToken;

    public static void getOutreachData(){
        outreachActivities = new List<Outreach_Activity__c>();
        
        Map<String, String> outreachMap =  new Map<String, String>();
        createOutreachActivities();
        if(outreachActivities.size() > 0){
            for(Outreach_Activity__c oa : (Outreach_Activity__c[])outreachActivities){
                outreachMap.put(oa.Id, oa.Type__c);
            }
            createOutreachUserDetails(JSON.serialize(outreachMap));
        }
    }

    public static void createOutreachActivities(){
        for(String type : mapFromRateTypeToProperties.keySet()){
            SObject sObj = Schema.getGlobalDescribe().get('Outreach_Activity__c').newSObject();
            sObj.put('Type__c', type);
            sObj.put('Start_Date__c', System.now().addDays(-7));
            sObj.put('End_Date__c', System.now());
            sObj.put('ISR_s_count__c', outreachUsers.get('ISR').size());
            sObj.put('Business_days__c', 5);
            outreachActivities.add(sObj);
        }

        if(outreachActivities.size() > 0){
            try{
                insert outreachActivities;
            }catch(Exception ex){
                //handle exceptions
            }
        }
    }

    @future(Callout=true)
    public static void createOutreachUserDetails(String outreachMapSerialized){
        List<SObject> outreachUserDetails = new List<Outreach_User_Detail__c>();
        getAccessToken();
        Map<String, String> outreachMap = (Map<String, String>)JSON.deserialize(outreachMapSerialized, Map<String, String>.class);
        Callable extension = (Callable) Type.forName('OutreachDynamicMethods').newInstance();
        for(String oaId : outreachMap.keySet()){
            String rateType = outreachMap.get(oaId);
            String userType = rateType == 'Growth' ? 'Growth' : 'ISR';
            List<OutputModel> finalOutput = new List<OutputModel>();
            for(Outreach_API_Properties__mdt oap : mapFromRateTypeToProperties.get(rateType)){
                Map<String, Object> arguments = new Map<String, Object>();
                String joinArguments = '';
                Integer counter = 0;
                for(String args: oap.Filter_Attributes__c.split(',')){
                    counter++;
                    String[] argMap = args.split('=');
                    Object argValue = '';
                    if(argMap.size() ==2 && argMap[1].contains('..')){
                        String[] rangeVars = argMap[1].split('\\.\\.');
                        argValue = argMap[0]+'='+dynamicAttributeValues.get(rangeVars[0])+'..'+dynamicAttributeValues.get(rangeVars[1]);
                    }else if(argMap.size() ==2 && dynamicAttributeValues.containsKey(argMap[1])){
                        argValue = argMap[0]+'='+dynamicAttributeValues.get(argMap[1]);
                    }else{
                        argValue = args;
                    }
                    joinArguments += argValue + '&';
                }
                arguments.put('params', joinArguments.removeEnd('&'));
                arguments.put('requestType', oap.Request_Type__c);
                
                if(oap.Method__c == 'retrieveCallRates'){ 
                    arguments.put('emails', outreachUsers.get('ISR').keySet());
                }else{
                    arguments.put('nextEndpoint', null);
                    arguments.put('output', null);
                }

                OutreachActivityIntegration.OutputModel output = new OutreachActivityIntegration.OutputModel();
                List<OutputModel> tempOutput = new List<OutputModel>();
                output.field = oap.Field__r.QualifiedApiName;
                output.rates = (Map<String, Integer> )extension.call(oap.Method__c, arguments);
                tempOutput.add(output);
                finalOutput.addAll(tempOutput); // to avoid heap size limit
            }
            System.debug('\n\n finalOutput: '+finalOutput+'\n\n');
            for(String mail : outreachUsers.get(userType).keySet()){
                SObject oaUser = Schema.getGlobalDescribe().get('Outreach_User_Detail__c').newSObject();
                oaUser.put('Member__c', outreachUsers.get(userType).get(mail));
                oaUser.put('Outreach_Activity__c', oaId);
                oaUser.put('Type__c', rateType);
                for(OutreachActivityIntegration.OutputModel op : finalOutput){
                    Integer rate = 0;
                    if(op.rates != null && op.rates.containsKey(mail)){
                        rate = op.rates.get(mail);
                    }
                    oaUser.put(op.field, rate);
                }
                outreachUserDetails.add(oaUser);
            }
            
        }

        if(outreachUserDetails.size() > 0){
            try{
                insert outreachUserDetails;
            }catch(Exception ex){
                //handle exceptions
            }
        }
    }

    public static HttpResponse sendHttpCallout(String apiFilter, String nextEndpoint){
        System.debug('\n Heap size 1: '+ Limits.getHeapSize() +'\n');
        String endpoint = nextEndpoint == null ? Label.Outreach_Base_URL + '/' + apiFilter : nextEndpoint;
        Decimal count = 0;
        Http http = new Http();
        HttpResponse res = new HttpResponse();
        HttpRequest req = new HttpRequest();
        System.debug('endpoint: '+endpoint+'\n\n');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer '+accesstoken);
        req.setHeader('Content-Type', 'application/vnd.api+json');
		req.setTimeout(120000);
        req.setEndpoint(endpoint);
        try{
            res = http.send(req);
            System.debug('\n Heap size 2: '+ Limits.getHeapSize() +'\n');
            if(res != null){
                return res;
            }
        }catch(Exception ex){
            //handle exceptions
        }
        return null;
    }

    private static void getAccessToken(){
        AuthenticationService.OAuth2 oauthInfo = AuthenticationService.retrieveAccessToken('Outreach API Credentials', false);
        accessToken = oauthInfo.access_token;

    }

    public void execute(SchedulableContext sc){
        OutreachActivityIntegration.getOutreachData();
    }

    public class OutputModel {
        public String field;
        public Map<String,Integer> rates;
    }

    /************************************************************************* GETTER/SETTER ***********************************************************************************/

    public static Map<String, Object> dynamicAttributeValues{
        get{
            if(dynamicAttributeValues == null){
                dynamicAttributeValues =  new Map<String, Object>();
                System.debug('outreachUsers: '+outreachUsers);
                String isrEmails = String.join(new List<String>(outreachUsers.get('ISR').keySet()),',');
                String growthEmails = String.join(new List<String>(outreachUsers.get('Growth').keySet()),',');
                String dripSequenceIds = String.join(mapFromSequenceGroupToId.get('Drip'), ',');
                String nondripSequenceIds = String.join(mapFromSequenceGroupToId.get('Non-Drip'), ',');
                String startDate = System.now().addDays(-7).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');// 
                String endDate = System.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''); 
                dynamicAttributeValues.put('isrEmails', isrEmails);
                dynamicAttributeValues.put('growthEmails', growthEmails);
                dynamicAttributeValues.put('startDate', startDate);
                dynamicAttributeValues.put('endDate', endDate);
                dynamicAttributeValues.put('dripSequenceIds', dripSequenceIds);
                dynamicAttributeValues.put('nondripSequenceIds', nondripSequenceIds);
            }
            return dynamicAttributeValues;
        }
        private set;
    }

    public static Map<String, Map<String, String>> outreachUsers{
        get{
            if(outreachUsers ==  null){
                outreachUsers = new Map<String, Map<String, String>>();
                Map<String, String> isrUserMap = new Map<String, String>();
                Map<String, String> growthUserMap = new Map<String, String>();
                for(User u : [SELECT Id, Email, Outreach_Enabled__c FROM User WHERE (Outreach_Enabled__c = 'ISR' OR Outreach_Enabled__c = 'Growth')]){
                    if(u.Outreach_Enabled__c == 'ISR'){
                        isrUserMap.put(u.Email.replace('.invalid', ''), u.Id);
                        outreachUsers.put(u.Outreach_Enabled__c, isrUserMap);
                    }else{
                        growthUserMap.put(u.Email.replace('.invalid', ''), u.Id);
                        outreachUsers.put(u.Outreach_Enabled__c, growthUserMap);
                    }
                }
            }
            return outreachUsers;
        }
        private set;
    }

    private static Map<String, List<Outreach_API_Properties__mdt>> mapFromRateTypeToProperties{
        get{
            if(mapFromRateTypeToProperties ==  null){
                mapFromRateTypeToProperties =  new Map<String, List<Outreach_API_Properties__mdt>>();
                for(Outreach_API_Properties__mdt oa : [SELECT Id, Filter_Attributes__c, Rate_type__c, Field__c, Method__c, Request_Type__c, Field__r.QualifiedApiName FROM Outreach_API_Properties__mdt WHERE Active__c =: True]){
                    if(!mapFromRateTypeToProperties.containsKey(oa.Rate_type__c)){
                        mapFromRateTypeToProperties.put(oa.Rate_type__c, new List<Outreach_API_Properties__mdt>{oa});
                    }else{
                        mapFromRateTypeToProperties.get(oa.Rate_type__c).add(oa);
                    }
                }
            }
            return mapFromRateTypeToProperties;
        }
        private set;
    }

    private static Map<String, List<String>> mapFromSequenceGroupToId{
        get{
            if(mapFromSequenceGroupToId == null){
                mapFromSequenceGroupToId =  new Map<String, List<String>>();
                for(Outreach_Sequence_Mappings__mdt sm : [SELECT Id, Sequence_Name__c, Sequence_Id__c, Sequence_Group__c FROM Outreach_Sequence_Mappings__mdt WHERE Active__c =: True]){
                    if(!mapFromSequenceGroupToId.containsKey(sm.Sequence_Group__c)){
                        mapFromSequenceGroupToId.put(sm.Sequence_Group__c, new List<String>{sm.Sequence_Id__c});
                    }else{
                        mapFromSequenceGroupToId.get(sm.Sequence_Group__c).add(sm.Sequence_Id__c);
                    }
                }
            }
            return mapFromSequenceGroupToId;
        }
        private set;
    }
}