/**
 * Cloud Functions entrypoint
 *
 * Endpoint contracts are preserved; implementation is split into focused modules.
 */

export { proxyImage, callGemini, analyzeMealImage } from "./ai";
export {
  autocompleteFoods,
  lookupFoodByBarcode,
  searchFoods,
} from "./fatsecret";
export { onRecipeCreated, searchRecipes } from "./recipes";
