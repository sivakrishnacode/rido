import { Injectable } from '@nestjs/common';
import type { Server } from 'socket.io';

/** Rooms: `user:<id>` (passenger), `driver:<id>` (driver offers), `trip:<id>` (both sides of a trip). */
@Injectable()
export class TripEventsService {
  private server: Server | null = null;

  /** Called by the gateway once the Socket.IO server is ready. */
  attach(server: Server): void {
    this.server = server;
  }

  toUser(userId: string, event: string, payload: unknown): void {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }

  toDriver(driverId: string, event: string, payload: unknown): void {
    this.server?.to(`driver:${driverId}`).emit(event, payload);
  }

  /**
   * Takes [driverId]'s sockets out of the trip's room once they are off the trip (dropped and reassigned): no more of
   * its locations, chat or updates, which carry the next driver's and the rider's details.
   */
  leaveTrip(tripId: string, driverId: string): void {
    this.server?.in(`driver:${driverId}`).socketsLeave(`trip:${tripId}`);
  }

  /** To the trip room and, when given, the driver's own room too (one broadcast: a socket in both gets it once). */
  toTrip(tripId: string, event: string, payload: unknown, driverId?: string | null): void {
    this.server?.to(driverId ? [`trip:${tripId}`, `driver:${driverId}`] : `trip:${tripId}`).emit(event, payload);
  }
}
