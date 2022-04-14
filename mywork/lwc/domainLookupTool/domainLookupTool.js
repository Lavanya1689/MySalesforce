import { LightningElement } from 'lwc';

export default class DomainLookupTool extends LightningElement {
    documentId;
    documentIdOnTab;
    showResults;
    error;
    value = '';
    title;
    tabType;
    showFileUpload;
    showSpinner;
    
    get acceptedCSVFormats() {
        return ['.csv'];
    }

    get options() {
        return [
            { label: 'Account', value: 'Account' },
            { label: 'Contact', value: 'Contact' }
        ];
    }

    uploadFileHandler(event){
        this.showSpinner = true;
        const uploadedFiles = event.detail.files;
        this.documentId = uploadedFiles[0].documentId;
        this.documentIdOnTab = this.tabType;
        this.showResults = true;
    }

    handleChange(event) {
        this.value = event.detail.value;
        this.showFileUpload = true;
        if(this.value == 'Account'){
            this.title = 'Domain Lookup';
            this.tabType = 'Account';
            if(this.documentId != null){
                this.showResults = this.documentIdOnTab == 'Contact' ? false : true;
            } 
        }
        else if(this.value == 'Contact'){
            this.title = 'Contact Lookup';
            this.tabType = 'Contact';
            if(this.documentId != null){
                this.showResults = this.documentIdOnTab == 'Account' ? false : true;
            }
        }
    }

    handleShowSpinner(event){
        console.log('showSpinner 2: '+this.showSpinner);
        this.showSpinner = event.detail;
    }
}