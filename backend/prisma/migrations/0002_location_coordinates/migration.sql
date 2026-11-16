-- Coordinates are stored as PostGIS geography points (longitude, latitude).
-- Existing records remain NULL until their owners provide precise coordinates.
ALTER TABLE "Address" ADD COLUMN IF NOT EXISTS point geography(Point,4326);
ALTER TABLE "VendorLocation" ADD COLUMN IF NOT EXISTS point geography(Point,4326);
CREATE INDEX IF NOT EXISTS "Address_point_gix" ON "Address" USING GIST (point);
CREATE INDEX IF NOT EXISTS "VendorLocation_point_gix" ON "VendorLocation" USING GIST (point);
