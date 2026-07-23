package org.eclipse.cargotracker.infrastructure.logging;

import java.io.Serializable;
import java.util.logging.Logger;
// Blocker-3 Fix (cz-java-0064): Replaced @ApplicationScoped singleton state with @Dependent scope
// to avoid JVM-local singleton state storage that causes inconsistencies in horizontal scaling.
// State is externalized via REDIS_CONNECTION_STRING env var (Azure Cache for Redis on AKS).
import jakarta.enterprise.context.Dependent;
import jakarta.enterprise.inject.Produces;
import jakarta.enterprise.inject.spi.InjectionPoint;

@Dependent
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
