import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // --- CORS ---
  app.enableCors({
    origin: '*', // Ajustar en producción
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // --- Validación global ---
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // --- Prefijo global del API ---
  app.setGlobalPrefix('v1');

  // --- Swagger / OpenAPI ---
  const config = new DocumentBuilder()
    .setTitle('Quincena API')
    .setDescription(
      'API REST para la app móvil de presupuesto quincenal Quincena. ' +
        'Gestiona ciclos quincenales, categorías, asignaciones de presupuesto ' +
        'y transacciones con soporte OCR.',
    )
    .setVersion('1.0')
    .addBearerAuth(
      { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      'Supabase JWT',
    )
    .addTag('profiles', 'Perfil del usuario autenticado')
    .addTag('financial-accounts', 'Cuentas bancarias, billeteras y efectivo')
    .addTag('categories', 'Categorías maestras de gasto')
    .addTag('budget-templates', 'Plantillas de presupuesto por período')
    .addTag('biweekly-cycles', 'Ciclos quincenales')
    .addTag('budget-allocations', 'Asignación de presupuesto por ciclo')
    .addTag('transactions', 'Registro de gastos y movimientos')
    .addTag('receipt-scans', 'Comprobantes y OCR')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document, {
    swaggerOptions: { persistAuthorization: true },
  });

  const port = process.env.PORT ?? 3000;
  await app.listen(port);

  console.log(`🚀 Quincena API running on: http://localhost:${port}/v1`);
  console.log(`📚 Swagger docs at:         http://localhost:${port}/api`);
}

bootstrap();
