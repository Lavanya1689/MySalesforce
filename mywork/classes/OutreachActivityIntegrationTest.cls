@isTest
class OutreachActivityIntegrationTest {
    
    @isTest
    static void validateOutreachIntegration(){
        String body= '{"data" : [{"attributes": {"mailboxAddress": "sawyer.covington@fasts.co"}}], "meta": {"count": 22}}';
        map<string,string> map_header = new map<string,string>();
        map_header.put('Authorization','1234567890');
        map_header.put('Content-Type','application/vnd.api+json');

        Test.setMock(HttpCalloutMock.class,  new GlobalHttpMock(200,body,map_header));
        OutreachActivityIntegration.getOutreachData();

        System.debug([SELECT Id FROM Outreach_Activity__c].size()==3);
         
    }
}