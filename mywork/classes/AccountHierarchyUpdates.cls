/*
    Author: Lavanya Tangati
    Date Created: Oct 6 2021
    Description: 
        ** Automation to assign the whole hierarchy when the top level parent is assigned
        ** Field to be updated: Owner, Territory, Region, Sales Segment, Sales Region should all match parent account
        ** should only happen when the top level parent is changed
*/
public class AccountHierarchyUpdates extends TriggerWorkflow{
    List<Account> qualifiedTopLevelParents =  new List<Account>();

    public override void execute(){
        if(!tc.hasExecuted('AccountHierarchyUpdates')) {
            qualify();
            if(!qualifiedTopLevelParents.isEmpty()){
                tc.setHasExecuted('AccountHierarchyUpdates');
                updateTopDownChildAccounts();
            }
        }
    }

    private void qualify(){
        for(Account a : (Account[])tc.newList){
            if(a.ParentId == null && tc.isChanged(a.Id, 'OwnerId,Territory__c,Region__c,Sales_Region__c,Sales_Segment__c')){
                qualifiedTopLevelParents.add(a);
            }
        }
    }

    private void updateTopDownChildAccounts(){
        Map<Id,AccountHierarchyNode> nodes = new Map<Id,AccountHierarchyNode>();
        Set<Id> parentAccIds = new Set<Id>();
        List<Account> allChildAccounts = new List<Account>();
        Integer hierarchyLevel = 0;

        for (Account a : qualifiedTopLevelParents) {
            nodes.put(a.Id, new AccountHierarchyNode(a));
            parentAccIds.add(a.Id);
        }
    
        while (hierarchyLevel < 3 && parentAccIds.size() > 0) {
            Map<Id,Account> childAccounts = new Map<Id,Account>([SELECT Id, ParentID, Name, OwnerId, Territory__c, Region__c, Sales_Region__c, Sales_Segment__c
                                                                FROM Account
                                                                WHERE ParentId IN :parentAccIds
                                                                ]);
    
            parentAccIds = childAccounts.keySet();
    
            for (Account acc : childAccounts.values()) {
                AccountHierarchyNode newNode = new AccountHierarchyNode(acc);
                nodes.put(acc.id, newNode);
                AccountHierarchyNode refNode = nodes.get(acc.parentId);
                refNode.children.add(newNode);
            }
            hierarchyLevel++;
        }

        for (Account topAcc : qualifiedTopLevelParents) {
            List<Account> childAccs = new List<Account>();
            AccountHierarchyNode refNode = nodes.get(topAcc.id);
            Set<Id> childAccIds = traverseChildren(refNode.children, nodes);
            
            for (Id refId : childAccIds) {
                Account childAcc = nodes.get(refId).node;
                childAcc.OwnerId = topAcc.OwnerId;
                childAcc.Territory__c = topAcc.Territory__c;
                childAcc.Region__c = topAcc.Region__c;
                childAcc.Sales_Region__c = topAcc.Sales_Region__c;
                childAcc.Sales_Segment__c = topAcc.Sales_Segment__c;
                childAccs.add(childAcc);
            }
            allChildAccounts.addAll(childAccs);
        }

        if(allChildAccounts.size() > 0){
            try{
                update allChildAccounts;
            }
            catch(Exception ex){
                ExceptionUtils.handleException(ex, true, false);
            }
        }
    }

    private static Set<Id> traverseChildren(List<AccountHierarchyNode> children, Map<Id,AccountHierarchyNode> nodes) {
        Set<Id> accIds = new Set<Id>();
        for (AccountHierarchyNode refNode : children) {
            accIds.add(refNode.node.id);
            accIds.addAll(traverseChildren(refNode.children, nodes));
        }
        return accIds;
    }

    public class AccountHierarchyNode {
        Account node;
        List<AccountHierarchyNode> children;
     
        AccountHierarchyNode(Account acc) {
            node = acc;
            children = new List<AccountHierarchyNode>();
        }
    }
}
