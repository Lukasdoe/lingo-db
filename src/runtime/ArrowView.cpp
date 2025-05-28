#include "lingodb/runtime/ArrowView.h"

#include <numeric>

#include <cstddef>

namespace {
static constexpr std::array<uint8_t, 4096> createValidData() {
   std::array<uint8_t, 4096> res;
   std::ranges::fill(res.begin(), res.end(), 0xff);
   return res;
}
static constexpr std::array<uint16_t, 65536> createDefaultSelectionVector() {
   std::array<uint16_t, 65536> res;
   std::iota(res.begin(), res.end(), 0);
   return res;
}
} // namespace
std::array<uint8_t, 4096> lingodb::runtime::ArrayView::validData = createValidData();
std::array<uint16_t, 65536> lingodb::runtime::BatchView::defaultSelectionVector = createDefaultSelectionVector();
