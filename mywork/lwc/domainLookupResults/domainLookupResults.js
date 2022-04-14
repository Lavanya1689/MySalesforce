import { LightningElement, api, wire } from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import { updateRecord } from 'lightning/uiRecordApi';
import readCSVFile from '@salesforce/apex/DomainLookupController.readCSVFile';
import tableColumns from '@salesforce/apex/DomainLookupController.tableColumns';
import search from '@salesforce/apex/DomainLookupController.search';
import updateSObjectLookupSearch from '@salesforce/apex/DomainLookupController.updateSObject';
import updateRoundRobin from '@salesforce/apex/DomainLookupController.updateRoundRobin';
import createUnMatchedAccounts from '@salesforce/apex/DomainLookupController.createUnMatchedAccounts';
import createUnMatchedContactsAsLeads from '@salesforce/apex/DomainLookupController.createUnMatchedContactsAsLeads';
import {refreshApex} from '@salesforce/apex';

export default class DomainLookupResults extends LightningElement {
    @api documentId;
    @api tabType;
    @api showSpinner;

    error;
    friendlyMessage;
    lookupresult;
    matchedData = [];
    unmatchedData;
    matchedColumns;
    unMatchedColumns;
    contactColumns;
    selectedRecords;
    draftValues = [];
    selectedRows;
    preSelected = [];
    rowNumberOffset;
    recordsToDisplay;
    openModal = false
    errors = [];
    isMultiEntry = false;
    maxSelectionSize = 1;
    searchresult;
    refreshData;
    refreshColumns;
    refreshContactData;
    modalHeader;
    searchSObject;
    tabObjType;
    initialSelection = [
        {
            id: 'na',
            sObjectType: 'na',
            icon: 'standard:lightning_component',
            title: 'Inital selection',
            subtitle: 'Not a valid record'
        }
    ];
    
    @wire(readCSVFile, { contentDocumentId: '$documentId', sObjectType: '$tabType'})
    accountData(result) {
        this.refreshData = result;
        this.selectedRecords = [];
        this.dispatchEvent(new CustomEvent('showspinner', { detail: false }));
        if (result.data) {  
            this.lookupresult = result.data;
            this.matchedData = result.data.matchedRecords;
            this.unmatchedData = result.data.unMatchedRecords;
            this.matchedColumns = result.data.matchedColumns;
            this.unMatchedColumns = result.data.unMatchedColumns;

            if (this.matchedData && this.matchedData.length > 0) {
                this.matchedData = this.matchedData.map(thisRow => {
                    let currentRow = Object.assign({}, thisRow);
                    console.log('currentRow id: '+JSON.stringify(currentRow['Id']).substring(1,4));
                    let objectprefix = JSON.stringify(currentRow['Id']).substring(1,4); //(1,4) because of leading "/"
                    let obectType =  objectprefix == '003' ? 'Contact' : objectprefix == '00Q' ? 'Lead' : ''; 
                    console.log('obectType id: '+obectType);
                    if(this.matchedColumns){
                        this.matchedColumns.forEach(col => {
                            if (col.hasOwnProperty('api')) {
                                let val = this.getFieldValueFromObject(currentRow, col.api);
                                if (col.type === 'url' && val && !col.externalLink) {
                                    val = '/' + val;
                                }
                                currentRow[col.fieldName] = val;
                            }
                            console.log('col: '+JSON.stringify(col));
                            if(col.fieldName === 'ObjectName'){
                                currentRow[col.fieldName] = obectType;
                            }
                        });
                    }
                    
                    return currentRow;
                });
            }
        }else if (result.error) {
            console.log('error in accountdata:'+JSON.stringify(result.error));
            this.error = result.error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading account',
                    message: result.error.message,
                    variant: 'error'
                })
            );
        } 
    }

     //GET THE FIELD VALUE IN GIVEN OBJECT
     getFieldValueFromObject(thisObject, fieldRelation) {
        let fieldRelationArray = fieldRelation.split('.');
        let objectFieldValue = thisObject;
        for (let f in fieldRelationArray) {
            if (objectFieldValue) {
                objectFieldValue = objectFieldValue[fieldRelationArray[f].trim()];
            }
        }
        return objectFieldValue;
    }

    @wire(tableColumns, { tableName: 'domainMatchedAccounts' })
    wiredMatchedColumns;

     //GET THE FIELD VALUE IN GIVEN OBJECT
     getFieldValueFromObject(thisObject, fieldRelation) {
        let fieldRelationArray = fieldRelation.split('.');
        let objectFieldValue = thisObject;
        for (let f in fieldRelationArray) {
            if (objectFieldValue) {
                objectFieldValue = objectFieldValue[fieldRelationArray[f].trim()];
            }
        }
        return objectFieldValue;
    }

    get usermessage(){
        return {
            init: 'Please wait...',
            noRecords: 'No Records Found',
            search: 'Searching...'
        };
    }


    handleSave(event) {
        this.draftValues = event.detail.draftValues;
        const recordInputs =   this.draftValues.slice().map(draft => {
            const fields = Object.assign({}, draft);
            return { fields };
        });
        
        var finalData = JSON.parse(JSON.stringify(recordInputs).replace(/\//ig, ''));
        const promises = finalData.map(recordInput => updateRecord(recordInput));
        Promise.all(promises).then(Accounts => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Accounts updated',
                    variant: 'success'
                })
            );
            this.draftValues = [];
            return this.refresh();
            // this.template.querySelector('c-lwc-datatable-utility').setRecordsOnPage(); 
        }).catch(error => {
            this.error = error;
            this.friendlyMessage = 'Error updating Account'
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating or reloading record',
                    message: JSON.stringify(error),
                    variant: 'error'
                })
            );  
        }).finally(() => {
            this.draftValues = [];
        });
    }

    handleOwnerChange(event){
        if(this.selectedRows){
            this.openModal = true;
            this.modalHeader = 'Choose Owner';
            this.searchSObject = 'User';
        }else{
            alert('please select rows');
        }
    }

    handleAddtoCampiagn(event){
        if(this.selectedRows){
            this.openModal = true;
            this.modalHeader = 'Choose Campaign';
            this.searchSObject = 'Campaign';
        }else{
            alert('please select rows');
        }
    }
    handleAddtoTopic(event){
        if(this.selectedRows){
            this.openModal = true;
            this.modalHeader = 'Choose Topic';
            this.searchSObject = 'Topic';
        }else{
            alert('please select rows');
        }
    }
    

    async confirmTheSearchEntry() {
        this.showSpinner = true;
        updateSObjectLookupSearch({recordId : this.searchresult[0].id, selectedRows: this.selectedRows, sObjectType: this.tabType})
        .then(result => {
            this.closeModal();
            this.showSpinner = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success!!',
                    message: 'Completed Successfully!',
                    variant: 'Success',
                }),
            );
            
            return this.refresh();
        })
        .catch(error => {
            this.error = error;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error!!',
                    message: JSON.stringify(error),
                    variant: 'error',
                }),
            );  
            this.closeModal();
        })
    }

    handleLookupSearch(event) {
        console.log('handleLookupSearch: '+JSON.stringify(event));
        const lookupElement = event.target;
        // Call Apex endpoint to search for records and pass results to the lookup
        search(event.detail)
        .then((results) => {
            lookupElement.setSearchResults(results);
            this.searchresult = results;
        })
        .catch((error) => {
            this.notifyUser('Lookup Error', 'An error occured while searching with the lookup field.', 'error');
            // eslint-disable-next-line no-console
            this.errors = [error];
        });
    }

    handleRoundRobin(event){
        if(this.selectedRows){
            this.showSpinner = !this.showSpinner;
            updateRoundRobin({selectedRows: this.selectedRows})
            .then(result => {
                this.showSpinner = !this.showSpinner;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!!',
                        message: 'Round Robin completed Successfully!',
                        variant: 'Success',
                    }),
                );
                return this.refresh();
            })
            .catch(error => {
                this.error = error;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error!!',
                        message: JSON.stringify(error),
                        variant: 'error',
                    }),
                );  
                
            })
            
        }else{
            alert('please select rows');
        }
    }

    handleTabClick(event){
        return refreshApex(this.refreshData);
    }

    createAccounts(event){
        if(this.selectedRecords){
            this.showSpinner = true
            createUnMatchedAccounts({selectedRecords: this.selectedRecords})
            .then(result => {
                this.showSpinner = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!!',
                        message: 'Accounts created Successfully!',
                        variant: 'Success',
                    }),
                );
                return this.refresh();
            })
            .catch(error => {
                this.error = error;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error!!',
                        message: JSON.stringify(error),
                        variant: 'error',
                    }),
                );  
                
            })
            
        }else{
            alert('please select rows');
        }
    }

    createLeads(event){
        if(this.selectedRecords){
            this.showSpinner = true
            createUnMatchedContactsAsLeads({selectedRecords: this.selectedRecords})
            .then(result => {
                this.showSpinner = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success!!',
                        message: 'Leads created Successfully!',
                        variant: 'Success',
                    }),
                );
                return this.refresh();
            })
            .catch(error => {
                this.error = error;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error!!',
                        message: JSON.stringify(error),
                        variant: 'error',
                    }),
                );  
                
            })
            
        }else{
            alert('Please select rows');
        }
    }

     //Capture the event fired from the paginator component
     handlePaginatorChange(event){
        this.recordsToDisplay = event.detail.recordsToDisplay;
        this.preSelected = event.detail.preSelected;
        if(this.recordsToDisplay && this.recordsToDisplay > 0){
            this.rowNumberOffset = this.recordsToDisplay[0].rowNumber-1;
        }else{
            this.rowNumberOffset = 0;
        } 
    }  

    handleAllSelectedRows(event) {
        this.selectedRows = [];
        const selectedItems = event.detail;          
        let items = [];
        selectedItems.forEach((item) => {
            this.showActionButton = true;
            items.push(item);
        });
        this.selectedRows = items;  
    } 

    handleGetSelectedRows(event){
        this.selectedRecords = event.detail;
    }

    notifyUser(title, message, variant) {
        if (this.notifyViaAlerts) {
            alert(`${title}\n${message}`);
        } else {
            const toastEvent = new ShowToastEvent({ title, message, variant });
            this.dispatchEvent(toastEvent);
        }
    }

    handleLookupSelectionChange(event) {
        this.checkForErrors();
    }

    checkForErrors() {
        this.errors = [];
        const selection = this.template.querySelector('c-lookup').getSelection();
        // Custom validation rule
        if (this.isMultiEntry && selection.length > this.maxSelectionSize) {
            this.errors.push({ message: `You may only select up to ${this.maxSelectionSize} items.` });
        }
        // Enforcing required field
        if (selection.length === 0) {
            this.errors.push({ message: 'Please make a selection.' });
        }
    }

   

    downloadCSVFile() { 
        this.showSpinner =  true;  
        let rowEnd = '\n';
        let csvString = '';
        // this set elminates the duplicates if have any duplicate keys
        let rowData = new Set();

        // getting keys from data
        this.matchedData.forEach(function (record) {
            Object.keys(record).forEach(function (key) {
                rowData.add(key);
            });
        });

        // Array.from() method returns an Array object from any object with a length property or an iterable object.
        rowData = Array.from(rowData);
        
        // splitting using ','
        csvString += rowData.join(',');
        csvString += rowEnd;

        // main for loop to get the data based on key value
        for(let i=0; i < this.matchedData.length; i++){
            let colValue = 0;

            // validating keys in data
            for(let key in rowData) {
                if(rowData.hasOwnProperty(key)) {
                    // Key value 
                    // Ex: Id, Name
                    let rowKey = rowData[key];
                    // add , after every value except the first.
                    if(colValue > 0){
                        csvString += ',';
                    }
                    // If the column is undefined, it as blank in the CSV file.
                    let value = this.matchedData[i][rowKey] === undefined ? '' : this.matchedData[i][rowKey];
                    
                    if(JSON.stringify(value).indexOf('/') === 1) { //remove leading "/" in the id fields
                        value = JSON.parse(JSON.stringify(value).replace(/\//ig, ''));
                    }

                    csvString += '"'+ value +'"';
                    colValue++;
                }
            }
            csvString += rowEnd;
        }

        // Creating anchor element to download
        let downloadElement = document.createElement('a');

        // This  encodeURI encodes special characters, except: , / ? : @ & = + $ # (Use encodeURIComponent() to encode these characters).
        downloadElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csvString);
        downloadElement.target = '_self';
        // CSV File Name
        downloadElement.download = 'Export Data.csv';
        // below statement is required if you are using firefox browser
        document.body.appendChild(downloadElement);
        // click() Javascript function to download CSV file
        downloadElement.click(); 

        this.showSpinner =  false;
    }

    closeModal() {
        this.openModal = false
    } 

    async refresh() {
        await refreshApex(this.refreshData);
    }
}