public class OutreachDynamicMethods implements Callable{
    static Map<String, String> callAnswered =  new Map<String, String>();
    public Object call(String action, Map<String, Object> args){
        switch on action {
            when 'retrieveRates' {
                return this.retrieveRates((String)args.get('requestType'), (String)args.get('params'),(Map<String, Integer>)args.get('output'), (String)args.get('nextEndpoint'));
            }
            when 'retrieveCallRates'{
                return this.retrieveCallRates((String)args.get('requestType'), (String)args.get('params'),(Set<String>)args.get('emails'));
            }
            // when 'retrieveClickCount' {
            //     return this.retrieveClickCount((String)args.get('requestType'), (String)args.get('filter1'), (String)args.get('filter2'), (String)args.get('filter3'));
            // }
            // when 'retrieveSequenceRates' {
            //     return this.retrieveSequenceRates((String)args.get('requestType'), (String)args.get('filter1'), (String)args.get('filter2'), (String)args.get('filter3'));
            // }
            when else {
                throw new ExtensionMalformedCallException('Method not implemented');
            }
        }
    }

    Map<String, Integer> retrieveRates(String requestType, String params, Map<String, Integer> output, String nextEndpoint) {
        HttpResponse res = OutreachActivityIntegration.sendHttpCallout(requestType + '?' + params, nextEndpoint);
        
        if(res != null){
            OutreachDataModel ord = (OutreachDataModel)System.JSON.deserialize(res.getBody(), OutreachDataModel.class);
            System.debug('ord:'+ord+'\n\n');
            for(OutreachData d : ord.data){
                if(output == null){
                    output = new Map<String, Integer>();
                }
                if(!output.containsKey(d.attributes.mailboxAddress)){
                    output.put(d.attributes.mailboxAddress, 0);
                }else{
                    output.put(d.attributes.mailboxAddress,output.get(d.attributes.mailboxAddress)+ 1); //increment
                }
            }
            if(ord.links != null && ord.links.next != null){
                retrieveRates(null, null, output, ord.links.next);
            }
        }
        return output;
    }

    //this method itself is designed differently. There is no directway we can pull the Call rates per user basis like the above "retrieveISRRates"
    //so we are looping through the ISR emails and sending a callout. No worries with the callout limits as -
    //The Outreach API is rate-limited on a per-user basis, with a fixed limit of 10,000 requests per one-hour period
    Map<String, Integer> retrieveCallRates(String requestType, String params, Set<String>  emails){
        Map<String, Integer> output = new Map<String, Integer>();
        for(String email : emails){
            HttpResponse res = OutreachActivityIntegration.sendHttpCallout(requestType + '?' + 'filter[user][email]='+email+'&' + params, null);
            if(res != null){
                OutreachDataModel ord = (OutreachDataModel)System.JSON.deserialize(res.getBody(), OutreachDataModel.class);
                output.put(email, Integer.valueOf(ord.meta.count));
            }
        }
        return output;
    }

    // Integer retrieveSequenceRates(String requestType, String filter1, String filter2, String filter3){
    //     Integer rates = 0;
    //     HttpResponse res = OutreachActivityIntegration.sendHttpCallout(requestType + '?' + filter1 + '&' + filter2 + '&' +filter3);
    //     if(res != null){
    //         OutreachDataModel ord = (OutreachDataModel)System.JSON.deserialize(res.getBody(), OutreachDataModel.class);
    //         rates = Integer.valueOf(ord.meta.count);
    //     }
    //     return rates;
    // }

    public class OutreachDataModel{
        public List<OutreachData> data;
        public Metadata meta;
        public Link links;
    }

    public class OutreachData{
        public Attributes attributes;
    }

    public class Attributes{
        public String mailboxAddress;
    }
    
    public class Metadata{
        public Decimal count;
    }

    public class Link{
        // public String first;
        // public String prev;
        public String next;
    }

    public class ExtensionMalformedCallException extends Exception {}
}