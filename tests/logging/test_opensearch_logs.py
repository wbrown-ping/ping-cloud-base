import re
import unittest
import subprocess
import time
import base64
import requests
import urllib3

from kubernetes import client, config
from opensearchpy import OpenSearch

class TestOpenSearchLogs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        # Load Kubernetes configuration
        config.load_kube_config()

        # Create Kubernetes client
        v1 = client.CoreV1Api()

        # Port-forward the OpenSearch service (opensearch-cluster-headless)
        cls.port_forward_process = subprocess.Popen(
            ["kubectl", "port-forward", "service/opensearch-cluster-headless", "9200:9200", 
             "-n", "elastic-stack-logging"], stdout=subprocess.PIPE
        )
        time.sleep(5)  # Give port-forwarding time to establish

        # Get OpenSearch credentials from the secret in the 'opensearch-admin-credentials' secret
        secret = v1.read_namespaced_secret("opensearch-admin-credentials", "elastic-stack-logging")
        username = base64.b64decode(secret.data['username']).decode('utf-8')
        password = base64.b64decode(secret.data['password']).decode('utf-8')
        response = requests.get(f"https://localhost:{9200}", verify=False, auth=(username, password))
        if response.status_code == 200:
            print("Port-forward established successfully.")
        else:
            raise Exception("Port-forward failed. Exiting test.")
        # Create OpenSearch client
        cls.opensearch_client = OpenSearch(
            hosts=[{'host': 'localhost', 'port': 9200}],
            http_auth=(username, password),
            use_ssl=True,  # Adjust SSL if needed
            verify_certs=False,
            ssl_show_warn = False,
            timeout=240 # in seconds
        )
        print("OpenSearch client created")

    @classmethod
    def tearDownClass(cls):
        # Terminate the port-forward process after the test suite runs
        cls.port_forward_process.terminate()

    def test_fluentbit_ingestion_field_timestamp(self):
        # Search logs in OpenSearch index template
        index_name = "logstash-*"  
        query = {
            "query": {
                "match_all": {}
            },
            "_source": ["fluentbit_ingest_timestamp"]
        }
        # Fetch indexes by regex
        response = self.opensearch_client.search(index=index_name, body=query)
        print(response)

        # Verify that the fluentbit_ingestion_field has a time in milliseconds
        for hit in response['hits']['hits']:
            timestamp_field = hit['_source'].get('fluentbit_ingest_timestamp')
            self.assertIsNotNone(timestamp_field, "fluentbit_ingest_timestamp is missing")
             # Validate timestamp format matches (YYYY-MM-DDTHH:MM:SS.SSSSSSSSSZ)
            timestamp_regex = r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,9}Z$'
            match = re.match(timestamp_regex, timestamp_field)
            self.assertTrue(
                match is not None,
                f"fluentbit_ingestion_field is not a valid timestamp: {timestamp_field}"
            )
if __name__ == '__main__':
    unittest.main()
