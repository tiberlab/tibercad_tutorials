/*  
 * This file is part of the tiberCAD module poisson.
 *
 * tiberCAD modules are licensed under the GNU General Public License v3.
 *
 * tiberCAD is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * tiberCAD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with tiberCAD. If not, see <http://www.gnu.org/licenses/>.
 */

/*!
 * \file Poisson.h
 * \brief tiberCAD poisson module header.
 *
 * \note This file is part of module poisson.
 */


#ifndef _POISSON_H_
#define _POISSON_H_

#include "tibercad/module/SimulationInterface.h"
#include "tibercad/solver/TiberLinearSystem.h"

#include "libmesh/enum_order.h"
#include "libmesh/enum_quadrature_type.h"

/*!
 * 
 * \brief This is an example implementation of the Poisson equation to
 *        help module development.
 *
 * Illustrates the basic usage of the SimulationInterface API.
 */
class TBDLLOCAL Poisson : public SimulationInterface
{

  public:

    //! Destructor
    /*!
     * We do not declare it virtual here, as we will not allow
     * to derive from this class anyway.
     */
    ~Poisson(void);

    //! We need a public static creator function
    static Poisson* create(const ModelOptions& options);



  protected:

    //! The initialization
    virtual void do_init(void) override final;


    //! Parse the options from the input file
    void parse_options(void);


    //! Setup the available variables
    virtual void do_setup_solution_variables(void) override final;


    //! Solve the Poisson equation
    virtual void do_solve(void) override final;


    //! Print some useful information
    virtual void do_print_info(void) override final;


    //! We need to create a physical model
    virtual PhysicalModel* create_bulk_model(const ModelOptions& options,
        const Material* mat) const override final;

    //! We need to create boundary condition model
    virtual PhysicalModel* create_boundary_model(const ModelOptions& options,
        const MaterialBoundary* boundary) const override final;


    //! We have to provide somehow our solution variables
    virtual void get_solution_secure(const Elem* elem,
        std::map<ID, std::vector<double> >& values,
        const std::vector<Point>& p) override final;



  private:

    //! These are the known solution variables
    /*!
     * This is an enum, but we use the string representation of 
     * the enum values to refer to solutions for plotting or 
     * for data exchange with other modules.
     *
     * \note Do \em not use (\c INVALID_ID - 1) or the strings \c RegionIDs
     * or \c materials as they are used to plot the materials/region IDs.
     *
     * \note The name "all" is used to plot all solutions
     */
    enum Solutions
    {
      Potential,        /*!< the potential */
      ElField,          /*!< the field (negative gradient of potential) */
      Displacement,     /*!< the electric displacement */
      Polarization,     /*!< the polarization field */
      ChargeDensity     /*!< the source (charge density) */
    };

    //! The constructor
    /*!
     * Being private disables further inheritance.
     */
    Poisson(const ModelOptions& options);

    //! The assembly function
    void assemble(void);

    //! A local helper class to be used to access assembly routine
    class MyAssembly : public TiberLinearSystem::Assembly
    {
      public:
        MyAssembly(Poisson* obj) : _obj(obj) {};

        void assemble() override
        {
          _obj->assemble();
        }

      private:
        Poisson *_obj;
    };

    MyAssembly _my_assembly;

    struct Options
    {

      /**
       * Set the default boundary conditions
       */
      std::string default_boundary_conditions;

      libMeshEnums::QuadratureType quadrature_type;

      libMeshEnums::Order integration_order;
    };

    Options myopts;
};





#endif // _POISSON_H_
