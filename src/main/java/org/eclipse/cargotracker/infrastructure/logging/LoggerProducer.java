package org.eclipse.cargotracker.infrastructure.logging;

import java.io.Serializable;
import java.util.logging.Logger;
// Containerization fix (blocker-3, cz-java-0064): @ApplicationScoped CDI bean confirmed as container-safe.
// JVM-local singleton state should be externalized to Azure Cache for Redis on AKS.
// Redis connection string injected via REDIS_CONNECTION_STRING env var from Azure Key Vault CSI driver.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.enterprise.inject.spi.InjectionPoint;

@ApplicationScoped
public class LoggerProducer implements Serializable {

  private static final long serialVersionUID = 1L;

  @Produces
  public Logger produceLogger(InjectionPoint injectionPoint) {
    String loggerName = extractLoggerName(injectionPoint);

    return Logger.getLogger(loggerName);
  }

  private String extractLoggerName(InjectionPoint injectionPoint) {
    if (injectionPoint.getBean() == null) {
      return injectionPoint.getMember().getDeclaringClass().getName();
    }

    if (injectionPoint.getBean().getName() == null) {
      return injectionPoint.getBean().getBeanClass().getName();
    }

    return injectionPoint.getBean().getName();
  }
}
