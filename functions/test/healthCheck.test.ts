import httpMocks from 'node-mocks-http';

import { healthCheck } from '../src/triggers/https/healthCheck';

describe('healthCheck', () => {
  it('responde 200 con status ok', () => {
    const request = httpMocks.createRequest({ method: 'GET' });
    const response = httpMocks.createResponse();

    healthCheck(request as never, response as never);

    expect(response.statusCode).toBe(200);
    expect(response._getJSONData()).toEqual({ status: 'ok' });
  });
});
