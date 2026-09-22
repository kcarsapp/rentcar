import express, { ErrorRequestHandler } from 'express';

import { errorHandler } from './middleware/errorHanlder';
import routes from './routes';
import cors from 'cors';
import { isAuthenticated } from './middleware/is_authenticated';
import { asyncErrorHandler } from './utils/async_wrap';
import 'dotenv/config';

const app = express();

// Older Android/iOS builds decode feature values as numbers. The API now
// stores localized catalog records (for example { en: "300", ku: "٣٠٠" }),
// so normalize those records only for Flutter/Dart clients. The web client
// continues to receive the full localized objects.
const mobileNumber = (value: unknown): unknown => {
  if (typeof value === 'number') return value;
  if (!value || typeof value !== 'object') return value;
  const record = value as Record<string, unknown>;
  const raw = record.en ?? record.ku ?? record.ar;
  if (typeof raw !== 'string' && typeof raw !== 'number') return value;
  const normalized = String(raw)
    .replace(/[٠-٩]/g, (digit) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(digit)))
    .replace(/[۰-۹]/g, (digit) => String('۰۱۲۳۴۵۶۷۸۹'.indexOf(digit)))
    .replace(/,/g, '')
    .trim();
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : value;
};

const normalizeMobilePayload = (
  value: unknown,
  options: { stripFeatured?: boolean } = {},
): unknown => {
  if (Array.isArray(value)) return value.map((item) => normalizeMobilePayload(item, options));
  // Preserve Date instances so Express can serialize them to ISO strings.
  // Treating a Date as a plain object turns it into {}, which breaks the
  // Flutter/iOS DateTime decoder for fields such as listedAt.
  if (value instanceof Date) return value;
  if (!value || typeof value !== 'object') return value;
  const input = value as Record<string, unknown>;
  // Prisma Decimal instances become plain `{ s, e, d }` objects when the
  // payload is recursively copied. Convert them to numbers for Dart models
  // such as RentalPlan.price and Car.rate.
  if ('s' in input && 'e' in input && 'd' in input && typeof (value as { toString?: unknown }).toString === 'function') {
    const parsed = Number(String(value));
    if (Number.isFinite(parsed)) return parsed;
  }
  const output: Record<string, unknown> = {};
  for (const [key, child] of Object.entries(input)) {
    if (key === 'feature' && child && typeof child === 'object') {
      const feature = { ...(child as Record<string, unknown>) };
      for (const numericKey of ['seat', 'hp', 'speed', 'odometer', 'cylinders', 'engCC']) {
        if (numericKey in feature) feature[numericKey] = mobileNumber(feature[numericKey]);
      }
      output[key] = normalizeMobilePayload(feature, options);
    } else if (key === 'company' && child && typeof child === 'object') {
      const company = { ...(child as Record<string, unknown>) };
      // Newer API responses may expose a compact KYC-only profile. The
      // installed mobile model expects a complete Profile object, so omit
      // this optional metadata when it cannot be decoded by that model.
      const profile = company.profile;
      if (profile && typeof profile === 'object' && !('userId' in (profile as Record<string, unknown>))) {
        delete company.profile;
      }
      output[key] = normalizeMobilePayload(company, options);
    } else if (key === 'featuredCars') {
      // Featured metadata is optional for the Suggested carousel. Older iOS
      // builds do not understand the newer featured-record shape; omitting
      // it keeps the car itself fully available without affecting the web.
      if (!options.stripFeatured) {
        output[key] = normalizeMobilePayload(child, options);
      }
    } else {
      output[key] = normalizeMobilePayload(child, options);
    }
  }
  return output;
};

// Global request logger - catches EVERY request
app.use((req, res, next) => {
  console.log(`\n🌐 ${new Date().toISOString()} - ${req.method} ${req.path}`);
  // Flutter's Dart IO client normally identifies as Dart; older iOS builds
  // can surface the underlying CFNetwork user-agent instead.
  if (/dart|flutter|cfnetwork/i.test(req.get('user-agent') ?? '')) {
    const json = res.json.bind(res);
    const stripFeatured = /\/suggestedCars$/.test(req.path);
    res.json = ((body: unknown) => json(normalizeMobilePayload(body, { stripFeatured }))) as typeof res.json;
  }
  next();
});

// DOMAIN may be a single origin or a comma-separated list (e.g. the consumer
// web domain plus the admin dashboard's dev/prod origins) — kept backwards
// compatible with the single-origin value this was before.
const allowedOrigins = (process.env.DOMAIN ?? '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization', 'devicelang', 'isCheking'],
    credentials: true,
    optionsSuccessStatus: 200,
  }),
);
app.use(express.json());

// Serve static files from /var/www/carvaweb.xyz/ at /carvaweb path
app.use('/carvaweb', express.static('/var/www/carvaweb.xyz'));

app.use('/api/v1/company', asyncErrorHandler(isAuthenticated()));
app.use('/api/v1/admin', asyncErrorHandler(isAuthenticated()));

app.use(routes());
// Routes
// Global error handler (should be after routes)
app.use(errorHandler as ErrorRequestHandler);

export default app;
