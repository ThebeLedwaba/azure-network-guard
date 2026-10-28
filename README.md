# Network Guard - Secure Azure Infrastructure

## 1. Project Overview
Network Guard is a secure, cloud-native Python (FastAPI) backend designed with a Zero-Trust architecture. The project demonstrates a full-stack approach to cloud security, combining a robust API with Infrastructure as Code (IaC) to provision a fully isolated Azure environment.

**Core Technologies:**
- **Backend:** Python 3.11, FastAPI, SQLAlchemy
- **Security:** JWT (JSON Web Tokens), Bcrypt password hashing
- **Cloud Infrastructure:** Microsoft Azure (VNet, App Service, Azure SQL)
- **Infrastructure as Code:** Terraform
- **Networking:** Private Endpoints, Private DNS Zones, VNet Integration

---

## 2. Architecture Design

The architecture follows a strict Zero-Trust model. The Azure SQL Database is completely locked from the public internet (`public_network_access_enabled = false`). It can only be accessed via a Private Endpoint located inside the Virtual Network.

### 2.1 Deployment Diagram (UML)

```mermaid
graph TD
    Client[Client / Internet] -->|HTTPS| AppService[Azure App Service\n(Python FastAPI)]
    
    subgraph Azure VNet ["Azure Virtual Network (10.0.0.0/16)"]
        subgraph AppSubnet ["snet-app (10.0.1.0/24)"]
            AppService
        end
        
        subgraph PEPS ["snet-private-endpoint (10.0.2.0/24)"]
            PE[Private Endpoint]
        end
        
        DNS[Private DNS Zone\nprivatelink.database.windows.net]
    end
    
    AppService -->|Private DNS Resolution| DNS
    AppService -->|Private Connection| PE
    PE -->|Internal Traffic| SQL[(Azure SQL Database\nPublic Access Disabled)]
sequenceDiagram
    participant User
    participant API as FastAPI (App Service)
    participant Auth as Auth Module (JWT)
    participant DB as Azure SQL (Private)

    User->>API: POST /register (email, password)
    API->>Auth: Hash password (bcrypt)
    Auth-->>API: Hashed Password
    API->>DB: INSERT INTO users
    DB-->>API: Success
    API-->>User: 201 Created

    User->>API: POST /login (email, password)
    API->>DB: SELECT * FROM users WHERE email=?
    DB-->>API: User Record (Hashed Password)
    API->>Auth: Verify Password
    Auth-->>API: Valid
    API->>Auth: Generate JWT Token
    Auth-->>API: Access Token
    API-->>User: 200 OK (JWT Token)

    User->>API: GET /secure-data (Bearer Token)
    API->>Auth: Validate Token
    Auth-->>API: Valid
    API-->>User: 200 OK (Secure Data)
   3. Infrastructure as Code (Terraform)
The entire Azure environment is provisioned using Terraform. The configuration is located in the terraform/ directory.

Resources Provisioned:

Resource Group: rg-network-guard

Virtual Network: vnet-network-guard (Address space: 10.0.0.0/16)

Subnets:

snet-app (Delegated to Microsoft.Web/serverFarms)

snet-private-endpoint (Hosts the Private Endpoint)

Azure SQL Server & Database: Basic tier, public access disabled.

Private Endpoint: Connects the SQL database securely to the VNet.

Private DNS Zone: privatelink.database.windows.net for internal resolution.

App Service Plan: Linux, Python 3.11 (Configured for B1 tier to support VNet integration).

4. Cloud Constraints (Azure for Students)
While the infrastructure is fully codified in Terraform, live deployment of the Web App was restricted due to Azure for Students subscription quota limits:

The F1 (Free) App Service tier does not support VNet Integration.

The B1 (Basic) tier quota increase was blocked by the student subscription policy.

The Terraform code represents a production-ready architecture. To deploy this in a standard enterprise environment with sufficient quotas, run terraform apply in the terraform directory.

5. Local Development Guide
To run the Python API locally without Azure dependencies:

Clone the repository:

bash
git clone https://github.com/YOUR_USERNAME/network-guard.git
cd network-guard
Create and activate a virtual environment:

bash
python -m venv venv
# Windows:
source venv/Scripts/activate
# Mac/Linux:
source venv/bin/activate
Install dependencies:

bash
pip install -r requirements.txt
Run the FastAPI server:

bash
uvicorn app.main:app --reload
Access the Swagger UI to test the endpoints:
Navigate to http://127.0.0.1:8000/docs

6. Repository Structure
text
network-guard/
├── app/
│   ├── __init__.py
│   ├── auth.py
│   ├── database.py
│   ├── main.py
│   └── models.py
├── terraform/
│   ├── main.tf
│   ├── providers.tf
│   └── variables.tf
├── .gitignore
├── README.md
└── requirements.txt 