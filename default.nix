{database_password,...}:
let
  applicationRoot = import ./app.nix;
  pkgs = import <nixpkgs>{};
  # change this as necessary or wipe and use ENV vars
  credentials = {
    project = "PROJECT_KEY";
    serviceAccount = "SERVICE_ACCOUNT";
    accessKey = "./pkey.pem";
  };
  db = {resources, pkgs, lib, ...}:{
    system.stateVersion = "20.03";
    networking.firewall.allowedTCPPorts = [ 5432 ];
    deployment.targetEnv = "gce";
    deployment.gce = credentials // {
      region = "europe-west1-b";
      tags = ["db"];
      network = resources.gceNetworks.lb-net;
      instanceType = "n1-standard-1";
      rootDiskSize = 30;
      rootDiskType = "ssd";
    };
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_10;
      enableTCPIP = true;
      authentication = pkgs.lib.mkForce ''
# TYPE  DATABASE        USER            ADDRESS                 METHOD
        local all all trust
        local all all peer
        local all all md5
        host all all ::1/128 trust
        host all all 127.0.0.1/32 md5
        host all all 192.168.4.0/24 md5
      '';
      initialScript = pkgs.writeText "backend-initScript" ''
        CREATE ROLE awuser WITH LOGIN CREATEDB CREATEROLE PASSWORD '${database_password}';
        CREATE DATABASE awdatabase;
        GRANT ALL PRIVILEGES ON DATABASE awdatabase TO awuser;
        \c awdatabase;
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
      '';
    };
  };
  awesome_app = { resources,nodes, lib,pkgs, ...}:  {
    system.stateVersion = "20.03";
    environment.variables={
      PHP_BIN="${pkgs.php}/sbin/php";
      APP_DIR="${./public}";
    };
    networking.firewall.allowedTCPPorts = [ 80 ];
    deployment.targetEnv = "gce";
    deployment.gce = credentials // {
      region = "europe-west1-b";
      tags = [ "public-http" ];
      network = resources.gceNetworks.lb-net;
      instanceType="f1-micro";
      rootDiskSize = 50;
      rootDiskType = "ssd";
    };
    services.nginx= {
        enable = true;
        logError = "stderr";
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        enableReload = true;
        recommendedTlsSettings = true;
        statusPage = true;
        virtualHosts = {
          emrexyz = {
            default = true;
            root = applicationRoot;
            extraConfig = ''
              index index.php;
              location ~ \.php(/|$){
                fastcgi_pass unix:/run/phpfpm/app.sock;
                include ${pkgs.nginx}/conf/fastcgi_params;
                include ${pkgs.nginx}/conf/fastcgi.conf;
                fastcgi_split_path_info ^(.+\.php)(/.*)$;
                fastcgi_param DATABASE_URL pgsql://dbuser:${database_password}@localhost:5432/dbname;
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                fastcgi_buffer_size 256k;
                fastcgi_buffers 256 16k;
              }
            '';
          };
        };
    };
    services.redis = {
      enable= true;
      bind = "0.0.0.0";
    };
    services.phpfpm.pools.app.phpOptions = ''
      memory_limit = 256M
      date.timezone = Europe/Istanbul
      zend_extension = "${pkgs.php}/lib/php/extensions/opcache.so"
      extension = "${pkgs.php73Packages.redis}/lib/php/extensions/redis.so"
    '';
    services.phpfpm.pools.app.user = "nobody";
    services.phpfpm.pools.app.extraConfig = ''
      pm = dynamic
      pm.max_children = 32
      pm.max_requests = 500
      pm.start_servers = 2
      pm.min_spare_servers = 2
      pm.max_spare_servers = 5
      listen.owner = nginx
      listen.group = nginx
      php_admin_value[error_log] = 'stderr'
      php_admin_flag[log_errors] = on
      env[PATH] = ${lib.makeBinPath [ pkgs.php ]}
      catch_workers_output = yes
    '';
  };

in 
{

  # create a network that allows SSH traffic(by default), pings
  # and HTTP traffic for machines tagged "public-http"
  resources.gceNetworks.lb-net = credentials // {
    addressRange = "192.168.4.0/24";
    firewall = {
      allow-http = {
        targetTags = [ "public-http" "db"];
        allowed.tcp = [];
      };
      allow-ping.allowed.icmp = null;
    };
  };

  # by default, health check pings port 80, so we don't have to set anything
  resources.gceHTTPHealthChecks.plain-hc = credentials;

  resources.gceTargetPools.backends = { resources, nodes, ...}: credentials // {
    region = "europe-west1";
    healthCheck = resources.gceHTTPHealthChecks.plain-hc;
    machines = with nodes; [ backend1 backend2 backend3 ];
  };
  resources.gceTargetPools.databases = {resources, nodes, ...}: credentials // {
    region = "europe-west1";
    machines = with nodes; [ database ];
  };

  resources.gceForwardingRules.lb = { resources, ...}: credentials // {
    protocol = "TCP";
    region = "europe-west1";
    portRange = "80";
    targetPool = resources.gceTargetPools.backends;
    description = "Alternative HTTP Load Balancer";
  };

  backend1 = awesome_app;
  backend2 = awesome_app;
  backend3 = awesome_app;
  database = db;

}
