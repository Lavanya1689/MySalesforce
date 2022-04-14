public class DomainLookupController {
    private final static Integer MAX_RESULTS = 5;

    @AuraEnabled(cacheable=true)
    public static TableData readCSVFile(Id contentDocumentId, String sObjectType){
        list<SObject> accContactRecords = new list<SObject>();
        list<SObject> matchedRecords = new list<SObject>();
        list<SObject> unMatchedRecords = new list<SObject>();
        Set<String> queryFilter = new Set<String>();
        Set<String> fieldsApis = new Set<String>();
        TableData tableData;
        if(contentDocumentId != null) {
            ContentVersion objVersion = [SELECT Id, VersionData FROM ContentVersion WHERE ContentDocumentId =:contentDocumentId];
            list<String> csvLines = objVersion.VersionData.toString().split('\n');

            for(Integer i = 1; i < csvLines.size(); i++){
                if(String.isNotEmpty(csvLines[i].split(',')[0])){
                    queryFilter.add(csvLines[i].split(',')[0].trim().toLowercase());
                }
            }

            String tableName = sObjectType == 'Account' ? 'domainMatchedAccounts' : 'matchedContacts';
            for(LWC_Table_Column_Attributes__mdt col : FastUtil.tableColumnAttributes.get(tableName)){
                fieldsApis.add(col.Field_API__c);
            }
            
            fieldsApis.remove('ObjectName');
            List<String> fieldList = new List<String>(fieldsApis);
            String filterField = sObjectType == 'Account' ? 'Domain__c' : 'Email';
            String query = 'SELECT '+ String.join(fieldList, ',') + ' FROM '+ sObjectType +' WHERE ' + filterField + ' IN: queryFilter';

            matchedRecords.addALL((List<SObject>)Database.query(query)); 
            for(SObject sObj :matchedRecords){
                
                String rowValue = (String)sObj.get(filterField);
                if(queryFilter.contains(rowValue)){
                    queryFilter.remove(rowValue);
                }
            }

            if(sObjectType == 'Account'){
                for(String d : queryFilter){
                    Account a = new Account(Name = d, Website = 'www.'+d);
                    unMatchedRecords.add(a);
                }
            }
            else if(sObjectType == 'Contact'){
                //IF THERE ARE no matched contacts look for matched Leads with email
                fieldsApis.remove('AccountId');
                fieldsApis.remove('Account.Name');
                query = 'SELECT '+ String.join(new List<String>(fieldsApis), ',') + ' FROM LEAD WHERE ' + filterField + ' IN: queryFilter';
                List<Sobject> leads =  Database.query(query);
                matchedRecords.addAll((List<sObject>)leads);

                for(SObject sObj :matchedRecords){
                    String rowValue = (String)sObj.get(filterField);
                    for(Integer i = 1; i < csvLines.size(); i++){
                        String row = csvLines[i];
    
                        if(rowValue != null && row.contains(rowValue)){
                            csvLines.remove(i);
                        } 
                    }
                }
                for(Integer i = 1; i < csvLines.size(); i++){
                    list<String> csvRowData = csvLines[i].split(',');
                    Lead l = new Lead();
                    l.Email = csvRowData[0];
                    l.FirstName = csvRowData[1];
                    l.LastName = csvRowData[2];
                    l.Company = csvRowData[3];
                    l.Website = csvRowData[4];
                    unMatchedRecords.add(l);
                }

            }
            tableData =  new TableData(matchedRecords, unMatchedRecords, sObjectType);
        }
        return tableData;    
    }

    @AuraEnabled(cacheable=true)
    public static LWCDataModels.TableColumn[] tableColumns(String tableName) {
        LWCDataModels.TableColumn[] fields = new List<LWCDataModels.TableColumn>();
        for (LWC_Table_Column_Attributes__mdt mdt : FastUtil.tableColumnAttributes.get(tableName)) {
            fields.add(new LWCDataModels.TableColumn(mdt));
        }

        return fields;//JSON.serialize(fields);
    }

    @AuraEnabled
    public static List<SObject> updateSObject(String recordId, List<Object> selectedRows, String sObjectType) {
    
        List<SObject> sobjects =  new List<SObject>();
        List<Map<Object, Object>> records = new List<Map<Object, Object>>();
        for(Object obj : selectedRows){
            records.add((Map<Object, Object>)obj);
           
        }

        for(Map<Object, Object> rec : records){
            String sObjId = String.valueOf(rec.get('Id')).replace('/', '');
            if(recordId.substring(0,3)== User.sObjectType.getDescribe().getKeyPrefix()){
                if(sObjectType == 'Contact'){
                    if(sObjId.substring(0,3) == '00Q'){
                        sObjectType = 'Lead';
                    }
                }
                sObject sObj = Schema.getGlobalDescribe().get(sObjectType).newSObject() ;
                sObj.Id = sObjId;
                sObj.put('OwnerId', recordId.replace('/', ''));
                sobjects.add(sObj);
            }
            else if((sObjectType == 'Contact' || sObjectType == 'Account') && recordId.substring(0,3)== Campaign.sObjectType.getDescribe().getKeyPrefix()){
                sObject sObj = Schema.getGlobalDescribe().get('CampaignMember').newSObject() ;
                sObj.put('CampaignId', recordId.replace('/', ''));
                if(sObjId.substring(0,3) == '003'){
                    sObj.put('ContactId', sObjId);
                }else if (sObjId.substring(0,3) == '001'){
                    sObj.put('AccountId', sObjId);
                }else{
                    sObj.put('LeadId', sObjId);
                }
                sobjects.add(sObj);
            }
            //No longer supporting Topics on Accounts from Domain Lookup Tool
            else if(sObjectType == 'Account' && recordId.substring(0,3)== Topic.sObjectType.getDescribe().getKeyPrefix()){
                sObject sObj = Schema.getGlobalDescribe().get('TopicAssignment').newSObject() ;
                sObj.put('TopicId', recordId.replace('/', ''));
                sObj.put('EntityId', sObjId);
                sobjects.add(sObj);
            }
        }
        upsert sobjects;
        return sobjects;
    }

    @AuraEnabled
    public static List<Account> updateRoundRobin(List<Object> selectedRows) {
        List<Account> accounts =  new List<Account>();
        List<Map<Object, Object>> records = new List<Map<Object, Object>>();
        for(Object obj : selectedRows){
            records.add((Map<Object, Object>)obj);
        }

        for(Map<Object, Object> rec : records){
            Account acc =  new Account(id = String.valueOf(rec.get('Id')).replace('/', ''));
            acc.Assign_Round_Robin__c = true;
            accounts.add(acc);
        }
        update accounts;
        return accounts;
    } 

    @AuraEnabled
    public static List<Account> createUnMatchedAccounts(List<Object> selectedRecords) {
        List<Sobject> accounts =  new List<Sobject>();
        List<Map<Object, Object>> records = new List<Map<Object, Object>>();
        for(Object obj : selectedRecords){
            records.add((Map<Object, Object>)obj);
        }

        for(Map<Object, Object> rec : records){
            SObject acc =  Schema.getGlobalDescribe().get('Account').newSObject();
            for(Object apiName: rec.keySet()){
                acc.put(String.valueOf(apiName), String.valueOf(rec.get(apiName)));
            }
            acc.put('Assign_Round_Robin__c', true);
            acc.put('OwnerId',Label.Kicksaw_OwnerId);
            accounts.add(acc);
        }
        insert accounts;
        return accounts;
    }

    @AuraEnabled
    public static List<Account> createUnMatchedContactsAsLeads(List<Object> selectedRecords) {
        List<Sobject> leads =  new List<Sobject>();
        List<Map<Object, Object>> records = new List<Map<Object, Object>>();
        for(Object obj : selectedRecords){
            records.add((Map<Object, Object>)obj);
        }

        for(Map<Object, Object> rec : records){
            SObject l =  Schema.getGlobalDescribe().get('Lead').newSObject();
            for(Object apiName: rec.keySet()){
                l.put(String.valueOf(apiName), String.valueOf(rec.get(apiName)));
            }
            l.put('OwnerId',Label.Kicksaw_OwnerId);
            leads.add(l);
        }
        insert leads;
        return leads;
    }


    @AuraEnabled(cacheable=true)
    public static List<LookupSearchResult> search(String searchTerm, List<String> selectedIds, String searchObject) {
        // Prepare query paramters
        searchTerm += '*';
        String searchquery = 'FIND :searchTerm IN ALL FIELDS RETURNING ' + searchObject + '(Id, Name WHERE id NOT IN :selectedIds) LIMIT 1';
        // Execute search query
        List<List<SObject>> searchResults = search.query(searchquery);

        // Prepare results
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        // Extract Accounts & convert them into LookupSearchResult
        String icon = 'standard:'+searchObject.toLowercase();
        SObject[] sobjects = (List<SObject>) searchResults[0];
        for (SObject sObj : sobjects) {
            String subtitle = sObj.get('Name') == null ? searchObject : searchObject + ' • ' + sObj.get('Name');
            results.add(new LookupSearchResult(sobj.Id, searchObject, icon, (String)sObj.get('Name'), subtitle));
        }

        // Optionnaly sort all results on title
        results.sort();
        return results;
    }

    public class TableData{
        @AuraEnabled public String matchedDataLabel;
        @AuraEnabled public String unMatchedDataLabel;
        @AuraEnabled public Boolean changeOwnerEnabled;
        @AuraEnabled public Boolean roundRobinEnabled;
        @AuraEnabled public Boolean exportCSVEnabled;
        @AuraEnabled public Boolean createCampaignsEnabled;
        @AuraEnabled public Boolean createAccountsEnabled;
        @AuraEnabled public Boolean createLeadsEnabled;
        @AuraEnabled public Boolean createTopicsEnabled;
        @AuraEnabled public List<SObject> matchedRecords;
        @AuraEnabled public List<SObject> unMatchedRecords;
        @AuraEnabled public LWCDataModels.TableColumn[] matchedColumns;
        @AuraEnabled public LWCDataModels.TableColumn[] unMatchedColumns;
        @AuraEnabled public LWCDataModels.TableColumn[] contactColumns;

        public TableData(List<SObject> matchedSObjects, List<SObject> unMatchedSObjects, String objectType){
            this.matchedRecords = matchedSObjects;
            this.unMatchedRecords = unMatchedSObjects;

            if(objectType == 'Account'){
                this.matchedDataLabel = 'Matched Accounts';
                this.unMatchedDataLabel = 'Unmatched Accounts';
                this.changeOwnerEnabled = true;
                this.roundRobinEnabled = true;
                this.exportCSVEnabled = true;
                this.createCampaignsEnabled = true;
                this.createAccountsEnabled =  true;
                this.createTopicsEnabled =  false;
                this.createLeadsEnabled =  false;
                this.matchedColumns = tableColumns('domainMatchedAccounts');
                this.unMatchedColumns = tableColumns('domainUnMatchedAccounts');
            }
            else if(objectType == 'Contact'){
                this.matchedDataLabel = 'Matched Contacts';
                this.unMatchedDataLabel = 'Unmatched Contacts';
                this.changeOwnerEnabled = true;
                this.roundRobinEnabled = false;
                this.exportCSVEnabled = true;
                this.createCampaignsEnabled = true;
                this.createAccountsEnabled =  false;
                this.createTopicsEnabled =  false; 
                this.createLeadsEnabled =  true;
                this.matchedColumns = tableColumns('matchedContacts');
                this.unMatchedColumns = tableColumns('unMatchedContacts');
            }
        }
    }
}