#!/bin/bash
# Use embedded signing
#
# Check that we're in a bash shell
if [[ $SHELL != *"bash"* ]]; then
  echo "PROBLEM: Run these scripts from within the bash shell."
fi

ds_access_token_path="config/ds_access_token.txt"
api_account_id_path="config/API_ACCOUNT_ID"
document_path="demo_documents/World_Wide_Corp_lorem.pdf"

if [ ! -f $ds_access_token_path ]; then
    ds_access_token_path="../config/ds_access_token.txt"
    api_account_id_path="../config/API_ACCOUNT_ID"
    document_path="../demo_documents/World_Wide_Corp_lorem.pdf"
fi

# Step 1: Obtain your OAuth token
# Note: Substitute these values with your own
ACCESS_TOKEN=$(cat ${ds_access_token_path})

# Set up variables for full code example
# Note: Substitute these values with your own
ACCOUNT_ID=$(cat ${api_account_id_path})


# Step 2. Create the envelope.
#         The signer recipient includes a clientUserId setting
#
#  document 1 (pdf) has tag /sn1/
#  The envelope will be sent to the signer.

base_path="https://demo.docusign.net/restapi"

# temp files:
request_data=$(mktemp /tmp/request-eg-001.XXXXXX)
response=$(mktemp /tmp/response-eg-001.XXXXXX)
doc1_base64=$(mktemp /tmp/eg-001-doc1.XXXXXX)

# Fetch doc and encode
cat $document_path | base64 > $doc1_base64

echo ""
echo "Sending the envelope request to DocuSign..."

# Concatenate the different parts of the request
#ds-snippet-start:eSign1Step2
printf \
'{
    "emailSubject": "Please sign this document set",
    "documents": [
        {
            "documentBase64": "' > $request_data
            cat $doc1_base64 >> $request_data
            printf '",
            "name": "Lorem Ipsum",
            "fileExtension": "pdf",
            "documentId": "1"
        }
    ],
    "recipients": {
        "signers": [
            {
                "email": "'"${SIGNER_EMAIL}"'",
                "name": "'"${SIGNER_NAME}"'",
                "recipientId": "1",
                "routingOrder": "1",
                "clientUserId": "1000",
                "tabs": {
                    "signHereTabs": [
                        {
                            "anchorString": "/sn1/",
                            "anchorUnits": "pixels",
                            "anchorXOffset": "20",
                            "anchorYOffset": "10"
                        }
                    ]
                }
            }
        ]
    },
    "status": "sent"
}' >> $request_data
#ds-snippet-end:eSign1Step2

# Step 3. Call DocuSign to create the envelope

#ds-snippet-start:eSign1Step3
curl --header "Authorization: Bearer ${ACCESS_TOKEN}" \
     --header "Content-Type: application/json" \
     --data-binary @${request_data} \
     --request POST ${base_path}/v2.1/accounts/${ACCOUNT_ID}/envelopes \
     --output ${response}
#ds-snippet-end:eSign1Step3

echo ""
echo "Response:" `cat $response`
echo ""

# pull out the envelopeId
envelope_id=`cat $response | grep envelopeId | sed 's/.*\"envelopeId\":\"//' | sed 's/\",.*//'`
echo "EnvelopeId: ${envelope_id}"

# Step 4. Create a recipient view (an embedded signing view)
#         that the signer will directly open in their browser to sign.
#
# The returnUrl is normally your own web app. DocuSign will redirect
# the signer to returnUrl when the DocuSign signing completes.
# For this example, we'll use http://httpbin.org/get to show the
# query parameters passed back from DocuSign

# temp files:
request_data=$(mktemp /tmp/request-eg-001.XXXXXX)
response=$(mktemp /tmp/response-eg-001.XXXXXX)

#ds-snippet-start:eSign1Step4
printf \
'{
    "returnUrl": "http://httpbin.org/get",
    "authenticationMethod": "none",
    "email": "'"${SIGNER_EMAIL}"'",
    "userName": "'"${SIGNER_NAME}"'",
    "clientUserId": 1000,
}' >> $request_data
#ds-snippet-end:eSign1Step4

# Step 5. Create the recipient view and call the API to initiate the signing

echo ""
echo "Requesting the url for the embedded signing..."
echo ""

#ds-snippet-start:eSign1Step5
Status=$(curl --header "Authorization: Bearer ${ACCESS_TOKEN}" \
     --header "Content-Type: application/json" \
     --data-binary @${request_data} \
     --request POST ${base_path}/v2.1/accounts/${ACCOUNT_ID}/envelopes/${envelope_id}/views/recipient \
     --output ${response})
#ds-snippet-end:eSign1Step5

if [[ "$Status" -gt "201" ]] ; then
    echo ""
	echo "Signing request failed."
	echo ""
	cat $response
	exit 0
fi

signing_url=`cat $response | grep url | sed 's/.*\"url\":\"//' | sed 's/\".*//'`
# ***DS.snippet.0.end
echo ""
echo "The embedded signing URL is ${signing_url}"
echo ""
echo "It is only valid for five minutes. Attempting to automatically open your browser..."

if which xdg-open &> /dev/null  ; then
  xdg-open "$signing_url"
elif which open &> /dev/null    ; then
  open "$signing_url"
elif which start &> /dev/null   ; then
  start "$signing_url"
fi

# cleanup
rm "$request_data"
rm "$response"
rm "$doc1_base64"

echo ""
echo "Done."