import { Request, Response, NextFunction } from 'express';
import { z, ZodSchema } from 'zod';

type Target = 'body' | 'params' | 'query';

export const validate =
  (schema: ZodSchema, target: Target = 'body') =>
  (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req[target]);
    if (!result.success) {
      const firstIssue = (result.error as z.ZodError).issues[0];
      const field = firstIssue?.path?.join('.') ?? 'input';
      const message = firstIssue?.message ?? 'Validation failed';
      res.status(400).json({
        success: false,
        error: `${field}: ${message}`,
        details: (result.error as z.ZodError).issues.map(i => ({
          field: i.path.join('.'),
          message: i.message,
        })),
      });
      return;
    }
    req[target] = result.data as any;
    next();
  };

// Common Zod schemas
export const ObjectIdSchema = z.string().regex(/^[0-9a-fA-F]{24}$/, 'Invalid ObjectId');

export const PaginationSchema = z.object({
  page:  z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const CitySchema = z.enum([
  'Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad',
  'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow',
]);
