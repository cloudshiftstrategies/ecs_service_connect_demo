<!DOCTYPE html>
<html>
<head>
    <title>Service Connect Demo</title>
    <style>
        .service-body {
            background-color: #e6f7ff;
        }
        .service-body.service-b {
            background-color: #ffe6e6;
        }
    </style>
</head>
<body class="service-body${service_type == "B" ? " service-b" : ""}">
    <h1>This is service${service_type} in ${cluster_name}</h1>
    <p>Container ID: <span id="containerId"></span></p>
    
    <div id="result">
        <h2>Service Discovery Test:</h2>
        <p>Click the button to test connection to service${other_service}</p>
        <button onclick="testServiceDiscovery()">Test Connection</button>
        <div id="response"></div>
    </div>

    <script>
        // Set container ID
        document.getElementById("containerId").textContent = window.location.hostname;

        function testServiceDiscovery() {
            document.getElementById("response").innerHTML = "<p>Testing connection...</p>";
            
            fetch("/proxy/service${other_service_lower}", {
                method: "GET"
            })
            .then(function(response) {
                return response.text();
            })
            .then(function(data) {
                const parser = new DOMParser();
                const htmlDoc = parser.parseFromString(data, "text/html");
                const title = htmlDoc.querySelector("h1").textContent;
                document.getElementById("response").innerHTML = 
                    "<p>Connected successfully! Response: " + title + "</p>";
            })
            .catch(function(error) {
                document.getElementById("response").innerHTML = 
                    "<p>Error: " + error + "</p>";
            });
        }
    </script>
</body>
</html> 