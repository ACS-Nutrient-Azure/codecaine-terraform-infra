import express, { Request, Response } from 'express';

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());

app.get('/health', (_req: Request, res: Response) => {
    res.json({
        status: 'healthy',
        service: 'frontend'
    });
});

app.get('/', (_req: Request, res: Response) => {
    res.json({
        service: 'frontend',
        message: 'Frontend service is running',
        version: '1.0.0'
    });
});

app.listen(PORT, () => {
    console.log(`Frontend service listening on port ${PORT}`);
});
