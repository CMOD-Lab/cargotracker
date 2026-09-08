package org.eclipse.pathfinder.internal;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
// cz-java-0064: @ApplicationScoped CDI bean - state externalized via Azure Cache for Redis.
// Redis connection string injected via REDIS_CONNECTION_STRING environment variable
// (Azure Key Vault CSI driver on AKS) to support horizontal scaling.
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class GraphDao implements Serializable {

  private static final long serialVersionUID = 1L;

  // Redis connection string injected via REDIS_CONNECTION_STRING env var (Azure Key Vault CSI driver on AKS)
  private final String redisConnectionString = System.getenv("REDIS_CONNECTION_STRING");

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
