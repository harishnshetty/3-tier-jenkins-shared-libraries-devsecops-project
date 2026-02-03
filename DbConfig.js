
async function getDbSecret() {
    console.log(`[DbConfig] Fetching secret from environment variables`);

    return {
        DB_HOST: process.env.DB_HOST,
        DB_PORT: process.env.DB_PORT || 3306,
        DB_USER: process.env.DB_USER,
        DB_PWD: process.env.DB_PWD,
        DB_DATABASE: process.env.DB_DATABASE
    };
}

module.exports = { getDbSecret };