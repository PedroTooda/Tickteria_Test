import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { DomainExceptionFilter } from './shared/domain-exception.filter';

async function bootstrap() {
  // rawBody: true é obrigatório — o HMAC é calculado sobre os bytes originais.
  const app = await NestFactory.create(AppModule, { rawBody: true });
  app.enableCors();
  app.useGlobalFilters(new DomainExceptionFilter());
  app.enableShutdownHooks();
  await app.listen(Number(process.env.API_PORT ?? 3001), '0.0.0.0');
}
void bootstrap();
