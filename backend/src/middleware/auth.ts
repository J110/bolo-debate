import { FastifyRequest, FastifyReply } from 'fastify';
import { JWTPayload } from '../types/index.js';

export async function authenticate(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    const token = request.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return reply.status(401).send({
        success: false,
        error: 'Authentication required',
      });
    }

    const decoded = request.server.jwt.verify<JWTPayload>(token);
    request.user = decoded;
  } catch (error) {
    return reply.status(401).send({
      success: false,
      error: 'Invalid or expired token',
    });
  }
}

export async function optionalAuth(
  request: FastifyRequest,
  _reply: FastifyReply
): Promise<void> {
  try {
    const token = request.headers.authorization?.replace('Bearer ', '');
    
    if (token) {
      const decoded = request.server.jwt.verify<JWTPayload>(token);
      request.user = decoded;
    }
  } catch {
    // Token is invalid, but that's okay for optional auth
    request.user = undefined;
  }
}
