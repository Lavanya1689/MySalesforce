@isTest
class DomainLookupControllerTest {
    @isTest
    static void validateDomainLookupControllerContact() {
        Account a = TestUtil.createAccount(true);
        Contact c = TestUtil.createContact(a, true);

        
        Blob bodyBlob = Blob.valueOf('test'); 
        ContentVersion cv = new Contentversion();
        cv.title='Test version 1.1';
        cv.PathOnClient ='test';
        cv.VersionData = bodyBlob;
        insert cv;

        cv = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        System.assert(DomainLookupController.readCSVFile(cv.ContentDocumentId, 'Contact') != null);

        List<Object> selectedRows =  new List<Object>();
        Map<Object, Object> row = new Map<Object, Object>{'Id' => c.Id};
        selectedRows.add((Object)row);
        System.assert(DomainLookupController.updateSObject(Label.Kicksaw_OwnerId, selectedRows, 'Contact')[0]!=null);
        System.assert(DomainLookupController.search('kicksaw', new List<String>{a.Id}, 'Contact') != null);

        List<Object> contactsrows =  new List<Object>();
        Map<Object, Object> conRow = new Map<Object, Object>{'LastName' => 'unmatched Account','Email' => 'test@test.comcom', 'Company' => 'www.test.com'};
        contactsrows.add((Object)conRow);

        System.assert(DomainLookupController.createUnMatchedContactsAsLeads(contactsrows).size() > 0);
    }

    @isTest
    static void validateDomainLookupControllerAccount() {
        Account a = TestUtil.createAccount(true);
        Contact c = TestUtil.createContact(a, true);

        Round_Robin__c rr = new Round_Robin__c();
        rr.Name = Constants.GROWTH_SALES_ROUND_ROBIN;
        rr.Active__c = true;
        insert rr;

        User u = [SELECT Id FROM User LIMIT 1];

        List<Round_Robin_Assignee__c>raList = new List<Round_Robin_Assignee__c>();
        Round_Robin_Assignee__c ra1 = new Round_Robin_Assignee__c();
        ra1.User__c = u.Id;
        ra1.Round_Robin__c = rr.Id;
        ra1.Active__c = true;
        raList.add(ra1);

        Round_Robin_Assignee__c ra2 = new Round_Robin_Assignee__c();
        ra2.User__c = u.Id;
        ra2.Round_Robin__c = rr.Id;
        ra2.Active__c = true;
        raList.add(ra2);

        insert raList;
        
        Blob bodyBlob = Blob.valueOf('test'); 
        ContentVersion cv = new Contentversion();
        cv.title='Test version 1.1';
        cv.PathOnClient ='test';
        cv.VersionData = bodyBlob;
        insert cv;

        cv = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        System.assert(DomainLookupController.readCSVFile(cv.ContentDocumentId, 'Account') != null);

        List<Object> selectedRows =  new List<Object>();
        Map<Object, Object> row = new Map<Object, Object>{'Id' => a.Id};
        selectedRows.add((Object)row);
        System.assert(DomainLookupController.updateSObject(Label.Kicksaw_OwnerId, selectedRows, 'Account')[0]!=null);
        System.assert(DomainLookupController.updateRoundRobin(selectedRows)[0].Assign_Round_Robin__c);
        System.assert(DomainLookupController.search('kicksaw', new List<String>{a.Id}, 'Account') != null);

        List<Object> accountsrows =  new List<Object>();
        Map<Object, Object> accRow = new Map<Object, Object>{'Name' => 'unmatched Account','Website' => 'www.test2.com'};
        accountsrows.add((Object)accRow);

        System.assert(DomainLookupController.createUnMatchedAccounts(accountsrows).size() > 0);
    }
}