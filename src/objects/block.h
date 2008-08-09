/**
 * \file   block.h
 * \brief  Configuration blocks API.
 * \author Copyright (c) 2002-2008 Jason Perkins and the Premake project
 *
 * \defgroup block Configuration Block
 * \ingroup  objects
 * @{
 */
#if !defined(PREMAKE_BLOCK_H)
#define PREMAKE_BLOCK_H

#include "fields.h"


/**
 * Configuration block field index.
 * \note If you modify this list, you must also update BlockFieldInfo[].
 */
enum BlockField
{
	BlockDefines,
	BlockObjDir,
	BlockTerms,
	NumBlockFields
};

extern struct FieldInfo BlockFieldInfo[];


DECLARE_CLASS(Block)

Block      block_create(void);
void       block_destroy(Block blk);

int        block_applies_to(Block blk, const char* cfg_name);
Fields     block_get_fields(Block blk);
Strings    block_get_values(Block blk, enum BlockField which);
void       block_set_values(Block blk, enum BlockField which, Strings strs);


#endif
/** @} */