-- ============================================================================
-- PostgreSQL Schema Migration for Recipe Embeddings
-- ============================================================================
-- 
-- This script updates the recipe_embeddings table to match the new schema.
-- Run this in your Cloud SQL instance before deploying updated functions.
--
-- To run:
--   1. Connect to Cloud SQL: gcloud sql connect recipe-vectors --user=postgres
--   2. Connect to database: \c recipes_db
--   3. Run this script: \i migrate_postgres.sql
--
-- ============================================================================

-- Add new nutrition columns if they don't exist
ALTER TABLE recipe_embeddings ADD COLUMN IF NOT EXISTS fiber INTEGER;
ALTER TABLE recipe_embeddings ADD COLUMN IF NOT EXISTS sugar INTEGER;
ALTER TABLE recipe_embeddings ADD COLUMN IF NOT EXISTS sodium INTEGER;

-- Remove deprecated dietary_labels column if it exists
-- (health_labels now contains all diet/allergy info)
ALTER TABLE recipe_embeddings DROP COLUMN IF EXISTS dietary_labels;

-- Verify the schema
\d recipe_embeddings;

-- Show current row count
SELECT COUNT(*) as total_recipes FROM recipe_embeddings;

-- ============================================================================
-- Expected final schema:
-- ============================================================================
--
--  Column       | Type        | Description
-- --------------+-------------+------------------------------------------
--  id           | text        | Primary key (spoonacular_XXXXX)
--  embedding    | vector(768) | Text embedding for semantic search
--  label        | text        | Recipe title
--  cuisine      | text        | Cuisine type
--  meal_types   | text[]      | Array of meal types
--  health_labels| text[]      | Diet/allergy labels
--  ingredients  | text[]      | Ingredient names
--  calories     | integer     | Per serving
--  protein      | integer     | Grams per serving
--  carbs        | integer     | Grams per serving
--  fat          | integer     | Grams per serving
--  fiber        | integer     | Grams per serving (NEW)
--  sugar        | integer     | Grams per serving (NEW)
--  sodium       | integer     | Mg per serving (NEW)
--
-- ============================================================================
