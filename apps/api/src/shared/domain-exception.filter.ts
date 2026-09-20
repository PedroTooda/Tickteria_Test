import { ArgumentsHost, Catch, ExceptionFilter, HttpStatus } from '@nestjs/common';
import { DomainError } from '@tickteira/core';
import type { Response } from 'express';

const STATUS: Record<string, number> = {
  EMPTY_ORDER: HttpStatus.BAD_REQUEST,
  SECTOR_NOT_FOUND: HttpStatus.NOT_FOUND,
  SECTOR_SOLD_OUT: HttpStatus.CONFLICT,
  INVALID_SIGNATURE: HttpStatus.UNAUTHORIZED,
  AMOUNT_MISMATCH: HttpStatus.CONFLICT,
};

@Catch(DomainError)
export class DomainExceptionFilter implements ExceptionFilter {
  catch(error: DomainError, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    const status = STATUS[error.code] ?? HttpStatus.UNPROCESSABLE_ENTITY;
    res.status(status).json({ error: error.code, message: error.message });
  }
}