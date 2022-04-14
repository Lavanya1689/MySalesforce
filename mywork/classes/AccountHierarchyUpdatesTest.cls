@isTest
class AccountHierarchyUpdatesTest {
    @isTest
    public static void validateChildHeirarchyAutomation() {
        //parent accs
        Account topAcc1 = TestUtil.createAccount(true);
        Account topAcc2 = TestUtil.createAccount(true);

        /************************************** Level 1 **************************************************/

            //Child accs for top Acc 1
            Account childAcc1 = TestUtil.createAccount(false);
            childAcc1.ParentID = topAcc1.Id;
            insert childAcc1;

            Account childAcc2 = TestUtil.createAccount(false);
            childAcc2.ParentID = topAcc1.Id;
            insert childAcc2;

            //Child accs for top Acc 2
            Account childAcc3 = TestUtil.createAccount(false);
            childAcc3.ParentID = topAcc2.Id;
            insert childAcc3;
    
            Account childAcc4 = TestUtil.createAccount(false);
            childAcc4.ParentID = topAcc2.Id;
            insert childAcc4;

        /************************************** Level 2 **************************************************/
            
            //Child acc for childAcc1
            Account childAcc5 = TestUtil.createAccount(false);
            childAcc5.ParentID = childAcc1.Id;
            insert childAcc5;

            //Child acc for childAcc4
            Account childAcc6 = TestUtil.createAccount(false);
            childAcc6.ParentID = childAcc4.Id;
            insert childAcc6;

        List<Account> updateAccs =  new List<Account>();
        Test.startTest();
            topAcc1.Sales_Region__c = 'US';
            updateAccs.add(topAcc1);
            topAcc2.Sales_Region__c = 'US';
            updateAccs.add(topAcc2);

            update updateAccs;
        Test.stopTest();

        for(Account a : [SELECT Id, Sales_Region__c FROM Account]){
            System.assert(a.Sales_Region__c == 'US');
        }
    }
}
