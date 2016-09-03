USE [rodbcext_test]
GO

DROP TABLE [dbo].[tbl_chracter_test_1]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[tbl_chracter_test_1](
	[id] [int] NOT NULL,
	[char_5] [varchar](5) NOT NULL,
	[char_255] [varchar](255) NOT NULL,
	[char_256] [varchar](256) NOT NULL,
	[char_8000] [varchar](8000) NOT NULL,
 CONSTRAINT [PK_tbl_chracter_test_1] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO


