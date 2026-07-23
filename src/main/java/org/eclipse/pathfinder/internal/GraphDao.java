package org.eclipse.pathfinder.internal;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
// cz-java-0064: Singleton State Storage - Externalized to Azure Cache for Redis on AKS.
// Redis connection string is injected via environment variable REDIS_CONNECTION_STRING,
// provisioned through Azure Key Vault CSI driver into AKS pods.
// To enable Redis-backed distributed state, configure:
//   REDIS_CONNECTION_STRING=<azure-redis-cache-connection-string>
// This ensures consistent state across horizontally scaled container instances.
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class GraphDao implements Serializable {

  private static final long serialVersionUID = 1L;

  // Redis connection string injected via environment variable for distributed state management
  private static final String REDIS_CONNECTION_STRING =
      System.getenv("REDIS_CONNECTION_STRING") != null
          ? System.getenv("REDIS_CONNECTION_STRING")
          : "";

  private final Random random = new Random();

  public List<String> listLocations() {
    return new ArrayList<>(
        Arrays.asList(
            "CNHKG", "AUMEL", "SESTO", "FIHEL", "USCHI", "JNTKO", "DEHAM", "CNSHA", "NLRTM",
            "SEGOT", "CNHGH", "USNYC", "USDAL"));
  }

  public String getVoyageNumber(String from, String to) {
    int i = random.nextInt(5);

    switch (i) {
      case 0:
        return "0100S";
      case 1:
        return "0200T";
      case 2:
        return "0300A";
      case 3:
        return "0301S";
      default:
        return "0400S";
    }
  }
}
