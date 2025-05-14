#include "lingodb/runtime/RecordBatchInfo.h"
#include <arrow/array.h>
#include <arrow/record_batch.h>
namespace {
uint8_t* getBufferOrAlternative(std::shared_ptr<arrow::ArrayData> arrayData, size_t bufferId) {
   static uint8_t alternative = 0b11111111;
   if (arrayData->buffers.size() > bufferId && arrayData->buffers[bufferId]) {
      auto* buffer = arrayData->buffers[bufferId].get();
      return (uint8_t*) buffer->address();
   } else {
      return &alternative; //always return valid pointer to at least one byte filled with ones
   }
}

void accessColumn(size_t colId, const std::shared_ptr<arrow::RecordBatch>& currChunk, lingodb::runtime::ColumnInfo& colInfo) {
   size_t off = currChunk->column_data(colId)->offset;
   colInfo.offset = off;
   colInfo.validBuffer = lingodb::runtime::RecordBatchInfo::getBuffer(currChunk.get(), colId, 0);
   colInfo.dataBuffer = lingodb::runtime::RecordBatchInfo::getBuffer(currChunk.get(), colId, 1);
   colInfo.varLenBuffer = lingodb::runtime::RecordBatchInfo::getBuffer(currChunk.get(), colId, 2);
   /*if (currChunk->column(colId)->type()->id() == arrow::Type::LIST) {
      auto childData = currChunk->column_data(colId)->child_data[0];
      colInfo.childInfo = new lingodb::runtime::ColumnInfo; //todo: fix
      colInfo.childInfo->offset = childData->offset;
      colInfo.childInfo->validBuffer = getBufferOrAlternative(childData, 0);
      colInfo.childInfo->dataBuffer = getBufferOrAlternative(childData, 1);
      colInfo.childInfo->varLenBuffer = getBufferOrAlternative(childData, 2);
   } else {
      colInfo.childInfo = nullptr;
   }*/
}
} //end namespace

uint8_t* lingodb::runtime::RecordBatchInfo::getBuffer(arrow::RecordBatch* batch, size_t columnId, size_t bufferId) {
   if (batch->column_data(columnId)->buffers.size() > bufferId && batch->column_data(columnId)->buffers[bufferId]) {
      auto* buffer = batch->column_data(columnId)->buffers[bufferId].get();
      return (uint8_t*) buffer->address();
   } else {
      return ColumnInfo::validData.data(); //always return valid pointer to at least one byte filled with ones
   }
}

lingodb::runtime::ColumnInfo lingodb::runtime::RecordBatchInfo::getColumnInfo(size_t columnId, const std::shared_ptr<arrow::RecordBatch>& currChunk) {
   lingodb::runtime::ColumnInfo info{};
   accessColumn(columnId, currChunk, info);
   return info;
}

void lingodb::runtime::RecordBatchInfo::access(std::vector<size_t> colIds, lingodb::runtime::RecordBatchInfo* info, const std::shared_ptr<arrow::RecordBatch>& currChunk) {
   for (size_t i = 0; i < colIds.size(); i++) {
      auto colId = colIds[i];
      lingodb::runtime::ColumnInfo* colInfo = info->columnInfos[i];
      accessColumn(colId, currChunk, *colInfo);
   }
   info->numRows = currChunk->num_rows();
}
static constexpr std::array<uint8_t ,4096> createValidData(){
   std::array<uint8_t ,4096> res;
   for(size_t i=0;i<4096;i++){
      res[i]=0xff;
   }
   return res;
}
std::array<uint8_t,4096> lingodb::runtime::ColumnInfo::validData=createValidData();