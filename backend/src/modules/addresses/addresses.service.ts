import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
@Injectable()
export class AddressesService {
  constructor(private readonly prisma:PrismaService){}
  list(userId:string){return this.prisma.address.findMany({where:{userId},orderBy:{createdAt:'desc'}});}
  create(userId:string,dto:{label?:string;details:string}){return this.prisma.address.create({data:{userId,label:dto.label,details:dto.details}});}
}
