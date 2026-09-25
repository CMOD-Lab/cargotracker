package org.eclipse.cargotracker.infrastructure.messaging.jms;

import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ejb.Stateless;
import org.eclipse.cargotracker.application.CargoInspectionService;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;

/**
 * Consumes Google Cloud Pub/Sub push messages and delegates notification of handled cargo
 * to the tracking service.
 *
 * <p>Replaces JMS MessageDriven bean with a REST endpoint that receives Pub/Sub push
 * notifications. Configure a Pub/Sub push subscription to deliver messages to
 * /pubsub/cargo-handled endpoint.
 *
 * <p>Environment variable GCS_PUBSUB_CARGO_HANDLED_SUBSCRIPTION should be set to the
 * Pub/Sub subscription name for cargo handled events.
 */
@Stateless
@Path("/pubsub")
public class CargoHandledConsumer {

  @Inject private Logger logger;

  @Inject private CargoInspectionService cargoInspectionService;

  /**
   * Receives Pub/Sub push messages for cargo handled events.
   * The message body contains the tracking ID of the handled cargo.
   */
  @POST
  @Path("/cargo-handled")
  @Consumes(MediaType.APPLICATION_JSON)
  public Response onMessage(PubSubMessage pubSubMessage) {
    try {
      String trackingIdString = pubSubMessage.getDecodedData();
      if (trackingIdString == null || trackingIdString.trim().isEmpty()) {
        logger.log(Level.WARNING, "Received empty Pub/Sub message for cargo-handled");
        return Response.status(Response.Status.BAD_REQUEST).build();
      }

      cargoInspectionService.inspectCargo(new TrackingId(trackingIdString.trim()));
      logger.log(Level.INFO, "Processed cargo-handled Pub/Sub message for tracking ID: {0}",
          trackingIdString);
      return Response.ok().build();
    } catch (Exception e) {
      logger.log(Level.SEVERE, "Error processing Pub/Sub message for cargo-handled", e);
      // Return 500 to trigger Pub/Sub retry
      return Response.serverError().build();
    }
  }
}
